<#
.SYNOPSIS
    Mettre en oeuvre la haute disponibilité pour machines virtuelles hébergées sur un hôte Hyper-V.

.DESCRIPTION
    Il existe plusieurs méthodes de tolérantes de pannes et de résilience pour machines virtuelles hébergées sur un hôte Hyper-V. 
    
    Hyper-V Replica fournit la réplique d’une VM exécutée sur un hôte Hyper-V pouvant être stockée et mise à jour sur un autre hôte Hyper-V. 
    La réplication est asynchrone (lagged copy) et aucun stockage partagé n’est nécessaire.
    
    RPO (Recovery Point Objective): Hyper-V Replica effectue une réplication initiale complète du disque virtuel. 
    Le différentiel des modifications est transmit à intervalles réguliers (30s par défaut). 
    
    Les points de récupération (horaire) sont optionnels et créés à partir des blocs modifiés, avec impact sur les ressources. 

    RTO (Recovery Time Objective): basculement manuel de la VM répliquée sur le serveur de réplica.


    Ce script illustre les étapes de configuration d’Hyper-V Replica et simule deux noeuds Hyper-V, "SRV-HYP-1" et "SRV-HYP-2".  

.NOTES
    Invoke-Command -FilePath ".\mon-script.ps1" -ComputerName "LAB-HYPERV" -Credential "LAB-HYPERV\Administrateur"
    
.LINK
    https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/manage/set-up-hyper-v-replica
#>

###
# ÉTAPE 0: Vérification de la mémoire avant création des VMs:
##
$computerName = $env:COMPUTERNAME
$os = Get-CimInstance win32_operatingsystem -Property TotalVisibleMemorySize,FreePhysicalMemory -Computername $computerName
$inUseMemory = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1kB
Write-Host "Used memory: $([math]::Round($inUseMemory/1GB,2))GB"

###
# ÉTAPE 1 : Création des 'vSwitch' pour le lab:
##
New-VMSwitch -Name "EXT-vSwitch-Lab" -SwitchType External -NetAdapterName "Ethernet" -AllowManagementOS $true
New-VMSwitch -Name "INT-vSwitch-Lab" -SwitchType Internal
New-VMSwitch -Name "PRV-vSwitch-Lab" -SwitchType Private

###
# ÉTAPE 2 : Création des VMs Hyper-V (SRV-HYP-1 et SRV-HYP-2):
##
param(
    [Parameter(Mandatory=$true)]
    [string]$VMName # SRV-HYP-1
)
$VirtualMachine = @{
    Name = $VMName
    MemoryStartupBytes = 2048MB
    Generation = 2
    NewVHDPath = "C:\Virtual Machines\$VMName\$VMName.vhdx"
    NewVHDSizeBytes = 20GB
    BootDevice = "VHD"
    Path = "C:\Hyper-V"
    #SwitchName = (Get-VMSwitch -Name "EXT-vSwitch").Name
    ErrorAction = "Stop"
}

$INTRoles = "Heartbeat", "Migration"
$EXTRoles = "Management", "Storage", "VM"
try {
    New-VM @VirtualMachine

    foreach ($role in $INTRoles) {
        $NetworkAdapters = @{
            VMName = $VMName    
            Name = "vNIC-{0}" -f $role
            SwitchName = "INT-vSwitch"
            ErrorAction = "Stop"
        }
        Add-VMNetworkAdapter @NetworkAdapters
    }
    foreach ($role in $EXTRoles) {
        $NetworkAdapters = @{
            VMName = $VMName    
            Name = "vNIC-{0}" -f $role
            SwitchName = "EXT-vSwitch"
            ErrorAction = "Stop"
        }
        Add-VMNetworkAdapter @NetworkAdapters
    }
    
    Add-VMDvdDrive -VMName $VMName -Path "E:\windows_server_2025.iso"
    Set-VMFirmware -VMName $VMName -BootOrder @(
        (Get-VMDvdDrive -VMName $VMName), 
        (Get-VMHardDiskDrive -VMName $VMName)
    )
}
catch {
    "`n"
    Write-Host $PSItem.Exception.Message -ForegroundColor Red
    Write-Host $PSItem.ScriptStackTrace -ForegroundColor Red
    "`n"
}

###
# ÉTAPE 3: Configuration réseau des VMs Hyper-V pour migration:
##
$SecurePassword = ConvertTo-SecureString "motDEpasse_1" -AsPlainText -Force
$Creds = New-Object System.Management.Automation.PSCredential ("SRV-HYP-1\Administrateur", $SecurePassword)
#$Creds = Get-Credential -Message "Entrez les identifiants de SRV-HYP-1"

<#
.SYNOPSIS
    Récupère l’état d’une VM.
#>
function Get-VMState {
    param (
        [string]$VMName
    )
    Write-Progress -Activity "Configuration de ${VMName}:" `
        -Status "Récupération de l’état de la VM..."
    #start-sleep -Seconds 2
    try {
        $VMState = (Get-VM -Name $VMName -ErrorAction Stop).State
        start-sleep -Seconds 1
        Write-Host "`nÉtat de la VM: ${VMState}`n" -ForegroundColor Cyan
    } catch {
        "`n"
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        "`n"
    }
    return $VMState    
}

<#
.SYNOPSIS
    Convertit l’adresse MAC délivrée par Hyper-V au format EUI-48 avec séparateur (-), selon la convention Windows.
.DESCRIPTION
    Capture dans le groupe $1 chaque paire de caractères '(.{2})' et remplace par '$1-', 
    à condition que ce qui suit corresponde (?=...) à au moins deux caractères quelconques .{2,},
    met en majuscule avec ToUpper().
#>  
function Convert-MacToDashFormat {
    param([string]$MAC)
    return ($MAC -replace '(.{2})(?=.{2,})', '$1-').ToUpper()
}

#
###
#

<# CONFIGURATION RÉSEAU POUR MIGRATION:
 Étapes:
 a. 
 b. 
 d. Récupérer l’alias réseau de 'vNIC-Migration' dans la VM via PowerShell Direct
 e. Configurer une adresse IP statique (sans passerelle, réseau privé)
#>

$VMName = "SRV-HYP-2"

# Configuration du VLAN 30 pour 'vNIC-Migration':
$VMNICName = "vNIC-Migration"
Write-Progress -Activity "Configuration de ${VMName}" `
    -Status "Configuration du VLAN sur ${VMNICName}..."
    start-sleep -Seconds 2
try {
    Set-VMNetworkAdapterVlan -VMName $VMName -VMNetworkAdapterName $VMNICName -Access -VlanId 30 `
        -ErrorAction Stop
} catch {
    "`n"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    "`n"
}

$VMState = Get-VMState -VMName $VMName
if ($VMState -ne "Off") {
    Write-Progress -Activity "Configuration de ${VMName}" `
        -Status "Arrêt en cours..."
    Stop-VM -Name $VMName -Force
    Start-Sleep -Seconds 3
}

# Récupération de l’adresse MAC de 'vNIC-Migration':
Write-Progress -Activity "Configuration de ${VMName}" `
    -Status "Récupération de l’adresse MAC de ${VMNICName}..."
    #start-sleep -Seconds 1
try {
    $VMNetworkAdapter = Get-VMNetworkAdapter -VMName $VMName -Name $VMNICName -ErrorAction Stop
    start-sleep -Seconds 1
} catch {
    "`n"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    "`n"
}
$MACAddress = Convert-MacToDashFormat -MAC $VMNetworkAdapter.MacAddress
Write-Host "`nAdresse MAC de ${VMNICName}: ${MACAddress}`n" -ForegroundColor Cyan

$VMState = Get-VMState -VMName $VMName
if ($VMState -eq "Off") {
    Write-Progress -Activity "Configuration de ${VMName}" `
        -Status "Démarrage de la VM..."
    Start-VM -Name $VMName
    Start-Sleep -Seconds 3
}

##
$VMState = Get-VMState -VMName "SRV-HYP-2"
if ($VMState -eq "Off") {
    Write-Progress -Activity "Configuration de "SRV-HYP-2"" `
        -Status "Démarrage de la VM..."
    Start-VM -Name "SRV-HYP-2"
    Start-Sleep -Seconds 3
}
###

# Récupération de l’alias réseau de 'vNIC-Migration':
Write-Progress -Activity "Configuration de ${VMName}" `
    -Status "Récupération de l'alias réseau de ${MACAddress}..."
try {
    $Name = Invoke-Command -VMName $VMName -Credential $Creds -ScriptBlock {
        param($MACAddress)
        Get-NetAdapter | Where-Object { $_.MacAddress -eq $MACAddress } | 
        Select-Object -ExpandProperty Name
    } -ArgumentList $MACAddress -ErrorAction Stop
    start-sleep -Seconds 2
    Write-Host "`nAlias réseau de ${VMNICName}: ${Alias}`n" -ForegroundColor Cyan
} catch {
    "`n"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    "`n"
}

# Configuration d’une adresse IP statique sur 'vNIC-Migration' et modification de l’alias réseau:
$Address = "10.0.30.12"
Write-Progress -Activity "Configuration de ${VMName}" `
    -Status "Modification de ${Name}..."
try {
    Invoke-Command -VMName $VMName -Credential $Creds -ScriptBlock {
        param(
            $Name, 
            $VMNICName, 
            $Address
        )

        $Alias = $Name
        if (-not (Get-NetAdapter -Name $VMNICName -ErrorAction SilentlyContinue)) {
            Write-Host "$Name est renommé en $VMNICName..."
            Rename-NetAdapter -Name $Name -NewName $VMNICName
            Start-Sleep -Seconds 2
            $Alias = $VMNICName
        } 
        else {
            Write-Host "$VMNICName existe déjà, utilisation de l'alias existant."
        }

        Write-Host "Configuration d’une IP statique sur $Alias..."
        if (-not (Get-NetIPAddress -IPAddress $Address -ErrorAction SilentlyContinue)) {
            New-NetIPAddress -InterfaceAlias $Alias -IPAddress $Address -PrefixLength 24
            #Set-DnsClientServerAddress -InterfaceAlias $Alias -ServerAddresses "10.0.30.10"
            Start-Sleep -Seconds 2
        }
        else {
            Write-Host "L'adresse IP $Address est déjà configurée."
        }

        Write-Host "Configuration de $Alias terminée."
    } -ArgumentList $Name, $VMNICName, $Address -ErrorAction Stop
}
catch {
    "`n"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    "`n"
}

####
## ÉTAPE 4: Configuration d’Hyper-V Replica sur les deux hôtes Hyper-V:
###

# Configuration du serveur replica SRV-HYP-2 (cible):
$ReplicaServer = "SRV-HYP-2"

# Activation de l’extension de virtualisation imbriquée pour le serveur cible (doit être arrêté): 
Set-VMProcessor -VMName $ReplicaServer -ExposeVirtualizationExtensions $true

# Vérification de l’activation de la virtualisation imbriquée pour le serveur cible :
Invoke-Command -VMName $ReplicaServer -Credential $Creds -ScriptBlock {
    Get-CimInstance -ClassName Win32_Processor | 
        Select-Object VirtualizationFirmwareEnabled
}    

# Vérification des prérequis pour Hyper-V Replica:
Write-Progress -Activity "Configuration de ${ReplicaServer}" `
    -Status "Vérification de prérequis..."
try {
    Invoke-Command -VMName $ReplicaServer -Credential $Creds -ScriptBlock {
        $folder = Test-Path -Path "C:\ReplicaStorage"    
        if (-not $folder) {
            Write-Host "Création du dossier de migration..." -ForegroundColor Cyan
            New-Item -ItemType Directory -Path "C:\ReplicaStorage" -Force
            Write-Host "`n"
        }
        $hvFeature = Get-WindowsFeature -Name Hyper-V -ErrorAction Stop
        if (-not $hvFeature.Installed) {
            Write-Host "Installation du rôle Hyper-V..." -ForegroundColor Cyan
            Install-WindowsFeature -Name Hyper-V -IncludeManagementTools `
                -ErrorAction Stop `
                -Restart
            start-sleep -Seconds 3
        }
    }
}    
catch {
    "`n"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    "`n"
}
#####    
Write-Progress -Activity "Configuration de ${ReplicaServer}" `
    -Status "Activation d'Hyper-V Replica..."
try {
    Invoke-Command -VMName $ReplicaServer -Credential $Creds -ScriptBlock {
        try {
            $server = "SRV-HYP-2"
            # Désactivation de la vérification CRL:
            #certutil -setreg chain\EnableRevocationCheck 0

            write-Host "`nGénération d’une chaîne de certificats pour notre serveur..." -ForegroundColor Cyan

            Write-Host "`nCréation d’un certificat racine..." -ForegroundColor Cyan
            $params = @{
                Type = 'Custom' 
                Subject = 'CN=SRV-HYP-2-Certificat-d-Autorité'
                TextExtension = @('2.5.29.19={text}CA=true')
                FriendlyName = "Certificat d’autorité SRV-HYP-2"
                KeyUsage = 'CertSign', 'CRLSign', 'DigitalSignature' 
                KeyAlgorithm = 'RSA'
                KeyLength = 2048
                CertStoreLocation = "Cert:\LocalMachine\My"
            }
            $ca = New-SelfSignedCertificate @params
            Start-Sleep -Seconds 2

            Write-Host "`nAjout du certificat au magasin 'Root'" -ForegroundColor Cyan
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
            $store.Open("ReadWrite")
            $store.Add($ca)
            $store.Close()
            Start-Sleep -Seconds 2

            Write-Host "`nCréation d’un certificat d’authentification pour ${server}..." -ForegroundColor Cyan
            $params = @{
                Type = 'Custom'
                Subject = 'CN=SRV-HYP-2'
                DnsName = 'SRV-HYP-2'
                KeyUsage = 'DigitalSignature'
                FriendlyName = "Certificat d’authentification de SRV-HYP-2"
                Signer = $ca
                CertStoreLocation = "Cert:\LocalMachine\My"
            }    
            $cert = New-SelfSignedCertificate @params            
            #$cert.Verify()

            start-sleep -Seconds 3

            $thumbprint = $cert.Thumbprint
            Write-Host "`nEmpreinte du certificat:" -ForegroundColor Cyan
            $thumbprint
        
            Write-Host "`nConfiguration d'Hyper-V Replica..." -ForegroundColor Cyan
            Set-VMReplicationServer -ReplicationEnabled $true `
                -AllowedAuthenticationType Certificate `
                -CertificateThumbprint $thumbprint `
                -DefaultStorageLocation "C:\ReplicaStorage" `
                -ReplicationAllowedFromAnyServer $true `
                #-ErrorAction Stop
            start-sleep -Seconds 3

            Write-Host "`nConfiguration d'Hyper-V Replica terminée." -ForegroundColor Green
            Get-VMReplicationServer        
        }
        catch {
            "`n"
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-Host $_.ScriptStackTrace -ForegroundColor Red
            Write-Host $_.ErrorDetails.Message -ForegroundColor Red    
            Write-Host $_.Exception.InnerException -ForegroundColor Red
            "`n"
        }
    }
}
catch {
    "`n"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    Write-Host $_.ErrorDetails.Message -ForegroundColor Red    
    Write-Host $_.Exception.InnerException -ForegroundColor Red
    "`n"
}
    
