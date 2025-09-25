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

# ÉTAPE 0: Vérification de la mémoire avant création des VMs:
$computerName = $env:COMPUTERNAME
$os = Get-CimInstance win32_operatingsystem -Property TotalVisibleMemorySize,FreePhysicalMemory -Computername $computerName
$inUseMemory = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1kB
Write-Host "Used memory: $([math]::Round($inUseMemory/1GB,2))GB"

# ÉTAPE 1 : Création des 'vSwitch' pour le lab:
New-VMSwitch -Name "EXT-vSwitch-Lab" -SwitchType External -NetAdapterName "Ethernet" -AllowManagementOS $true
New-VMSwitch -Name "INT-vSwitch-Lab" -SwitchType Internal
New-VMSwitch -Name "PRV-vSwitch-Lab" -SwitchType Private

# ÉTAPE 2 : Création des VMs Hyper-V (SRV-HYP-1 et SRV-HYP-2):
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

### ÉTAPE 3: CONFIGURATION RÉSEAU DES VMs HYPER-V
##              --- SRV-HYP-1 ---

# 3.0 Préparation des identifiants pour PowerShell Direct:
$SecurePassword = ConvertTo-SecureString "motDEpasse_1" -AsPlainText -Force
$Creds = New-Object System.Management.Automation.PSCredential ("SRV-HYP-1\Administrateur", $SecurePassword)
#$Creds = Get-Credential -Message "Entrez les identifiants de SRV-HYP-1"

<# 3.1 Configuration pour la migration:
 - a. Affecter 'vNIC-Migration' au VLAN 30 (segmentation logique)
 - b. Récupérer la MAC actuelle (dynamique) de 'vNIC-Migration' (nécessite que la VM soit éteinte)
 - c. Fixer 'vNIC-Migration' comme statique (évite perte IP en cas de reboot/migration)
 - d. Récupérer l’alias réseau de 'vNIC-Migration' dans la VM via PowerShell Direct
 - e. Configurer une adresse IP statique (sans passerelle, réseau privé)
#>
$VMName = "SRV-HYP-1"
Write-Progress -Activity "Configuration de ${VMName}:" `
    -Status "Récupération de l’état de la VM..."
    start-sleep -Seconds 2
try {
    $VMState = (Get-VM -Name $VMName -ErrorAction Stop).State
    Write-Host "`nÉtat de la VM: ${VMState}`n" -ForegroundColor Cyan

} catch {
    "`n"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    "`n"
}

$VMNICName = "vNIC-Migration"
Write-Progress -Activity "Configuration de ${VMName}" `
    -Status "Configuration du VLAN sur ${VMNICName}..."
try {
    Set-VMNetworkAdapterVlan -VMName $VMName -VMNetworkAdapterName $VMNICName -Access -VlanId 30 `
        -ErrorAction Stop
} catch {
    "`n"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    "`n"
}

if ($VMState -ne "Off") {
    Write-Progress -Activity "Configuration de ${VMName}" `
        -Status "Arrêt en cours..."
    Stop-VM -Name $VMName -Force
    Start-Sleep -Seconds 3
}

<#
.SYNOPSIS
    Convertit l’adresse MAC délivrée par Hyper-V au format EUI-48 avec séparateur (-), selon la convention Windows.
.DESCRIPTION
    Capture dans le groupe $1 chaque paire de caractères '(.{2})' et remplace par '$1:', 
    élimine le dernier séparateur (-) avec TrimEnd,
    met en majuscule avec ToUpper.
#>  
function Convert-MacToDashFormat {
    param([string]$MAC)
    return ($MAC -replace '(.{2})(?=.{2,})', '$1-').TrimEnd('-').ToUpper()
}

Write-Progress -Activity "Configuration de ${VMName}" `
    -Status "Récupération de l’adresse MAC de ${VMNICName}..."
try {
    $VMNetworkAdapter = Get-VMNetworkAdapter -VMName $VMName -Name $VMNICName -ErrorAction Stop
} catch {
    "`n"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    "`n"
}
$MACAddress = Convert-MacToDashFormat -MAC $VMNetworkAdapter.MacAddress

if ($VMState -eq "Off") {
    Write-Progress -Activity "Configuration de ${VMName}" `
        -Status "Démarrage de la VM..."
    Start-VM -Name $VMName -Force
    Start-Sleep -Seconds 3
}

Write-Progress -Activity "Configuration de ${VMName}" `
    -Status "Récupération de l'alias réseau de ${MACAddress}..."
try {
    $Alias = Invoke-Command -VMName $VMName -Credential $Creds -ScriptBlock {
        param($MACAddress)
        Get-NetAdapter | Where-Object { $_.MacAddress -eq $MACAddress } | 
        Select-Object -ExpandProperty Name
    } -ArgumentList $MACAddress -ErrorAction Stop
} catch {
    "`n"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    "`n"
}

$Address = "10.0.30.11"
Write-Progress -Activity "Configuration de ${VMName}" `
    -Status "Modification de ${Alias}..."
try {
    Invoke-Command -VMName $VMName -Credential $Creds -ScriptBlock {
        param($Alias, $VMNICName)
        if (-not (Get-NetAdapter -Name $VMNICName -ErrorAction SilentlyContinue)) {
            Write-Host "$Alias est renommé en $VMNICName..."
            Rename-NetAdapter -Name $Alias `
                -NewName $VMNICName
            $Alias = $VMNICName
        }   
        else {
            Write-Host "$VMNICName existe déjà. Utilisation de l'alias existant."
        }
        Write-Host "Configuration d’une IP statique sur $Alias..."
        New-NetIPAddress -InterfaceAlias $Alias -IPAddress $Address -PrefixLength 24
        #Set-DnsClientServerAddress -InterfaceAlias $Alias -ServerAddresses "10.0.30.10"
    } -ArgumentList $Alias, $VMNICName -ErrorAction Stop
} catch {
    "`n"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    "`n"
}
Write-Progress -Activity "Configuration de ${VMName}" -Completed -Status "Terminé."
#####
##
###
New-NetIPAddress -InterfaceAlias "vNIC-Management" -IPAddress 10.0.10.11 -PrefixLength 24
New-NetIPAddress -InterfaceAlias "vNIC-Cluster"    -IPAddress 10.0.20.11 -PrefixLength 24
New-NetIPAddress -InterfaceAlias "vNIC-Migration"  -IPAddress 10.0.30.11 -PrefixLength 24
New-NetIPAddress -InterfaceAlias "vNIC-Storage"    -IPAddress 10.0.50.11 -PrefixLength 24
New-NetIPAddress -InterfaceAlias "vNIC-VM"         -IPAddress 10.0.40.11 -PrefixLength 24


Get-NetAdapter | Format-Table -AutoSize

$InterfaceAliasNIC1 = "NIC-Mgmt"
$InterfaceAliasNIC2 = "NIC-Prod"

# Renommer les interfaces réseau sur chaque hôte si elles existent
if (Get-NetAdapter -Name "Ethernet" -ErrorAction SilentlyContinue) {
    Rename-NetAdapter -Name "Ethernet" -NewName $InterfaceAliasNIC1
}
if (Get-NetAdapter -Name "Ethernet 2" -ErrorAction SilentlyContinue) {
    Rename-NetAdapter -Name "Ethernet 2" -NewName $InterfaceAliasNIC2
}

# Configuration IP sur SRV-HV1
New-NetIPAddress -InterfaceAlias $InterfaceAliasNIC1    -IPAddress 10.0.10.11 -PrefixLength 24
New-NetIPAddress -InterfaceAlias $InterfaceAliasNIC2 -IPAddress 10.0.40.11 -PrefixLength 24 -DefaultGateway 10.0.40.1

# Configuration IP sur SRV-HV2
New-NetIPAddress -InterfaceAlias $InterfaceAliasNIC1    -IPAddress 10.0.10.12 -PrefixLength 24
New-NetIPAddress -InterfaceAlias $InterfaceAliasNIC2 -IPAddress 10.0.40.12 -PrefixLength 24 -DefaultGateway 10.0.40.1

# Désactiver NetBIOS et les services inutiles sur NIC-Gestion
Disable-NetAdapterBinding -Name $InterfaceAliasNIC1 -ComponentID ms_netbios
Disable-NetAdapterBinding -Name $InterfaceAliasNIC1 -ComponentID ms_server

<# ================================
ÉTAPE 2 : Installation des rôles
- Hyper-V
- Cluster de basculement
================================ #>

Install-WindowsFeature -Name Hyper-V, Failover-Clustering -IncludeManagementTools -Restart

<# ================================
ÉTAPE 3 : Création des vSwitch
- Un vSwitch par carte physique
- Pas d’accès à l’OS hôte
================================ #>

New-VMSwitch -Name "vSwitch-Gestion" -NetAdapterName $InterfaceAliasNIC1 -AllowManagementOS $false
New-VMSwitch -Name "vSwitch-Prod"    -NetAdapterName $InterfaceAliasNIC2 -AllowManagementOS $false

<# ================================
ÉTAPE 4 : Ajout des vNICs sur l’OS hôte
- Segmentation logique par VLAN
- Rôles : Management, Cluster, Migration, Stockage
================================ #>

# NIC-Gestion → VLAN 10 (Management) + VLAN 20 (Cluster)
Add-VMNetworkAdapter -ManagementOS -Name "vNIC-Management" -SwitchName "vSwitch-Gestion"
Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "vNIC-Management" -Access -VlanId 10

Add-VMNetworkAdapter -ManagementOS -Name "vNIC-Cluster" -SwitchName "vSwitch-Gestion"
Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "vNIC-Cluster" -Access -VlanId 20

# NIC-Production → VLAN 30 (Migration) + VLAN 40 (VM) + VLAN 50 (Stockage)
Add-VMNetworkAdapter -ManagementOS -Name "vNIC-Migration" -SwitchName "vSwitch-Prod"
Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "vNIC-Migration" -Access -VlanId 30

Add-VMNetworkAdapter -ManagementOS -Name "vNIC-Storage" -SwitchName "vSwitch-Prod"
Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "vNIC-Storage" -Access -VlanId 50

<# ================================
ÉTAPE 5 : Création du cluster
- Nom du cluster
- IP virtuelle sur le réseau de gestion
- Test de validation
================================ #>

New-Cluster -Name "Cluster-HV" -Node "SRV-HV1","SRV-HV2" -StaticAddress 10.0.10.100
Test-Cluster -Node "SRV-HV1","SRV-HV2"


Get-ClusterNode
Get-ClusterGroup
Get-ClusterNetwork

<# ================================
ÉTAPE 6 : Configuration des réseaux de cluster
- Définir les rôles des réseaux
- Activer SMB Multichannel
================================ #>

Set-SmbServerConfiguration -EnableSMBMultichannel $true

# Définir les rôles réseau dans le cluster
(Get-ClusterNetwork -Name "Cluster Network 1").Role = 1  # Cluster only (heartbeat)
(Get-ClusterNetwork -Name "Cluster Network 2").Role = 3  # Cluster and client (VM access)

<# ================================
ÉTAPE 7 : Ajout du stockage partagé
- Disques CSV
- Répertoire VM
================================ #>

Get-ClusterAvailableDisk | Add-ClusterDisk
Add-ClusterSharedVolume -Name "Cluster Disk 1"

# Exemple de création de VM sur le CSV
New-VM -Name "VM-Test01" -MemoryStartupBytes 512MB -Generation 2 `
-NewVHDPath "C:\ClusterStorage\Volume1\VM-Test01\disk.vhdx" `
-NewVHDSizeBytes 10GB -Path "C:\ClusterStorage\Volume1\VM-Test01"

Add-ClusterVirtualMachineRole -VirtualMachine "VM-Test01"

<# ================================
ÉTAPE 8 : Redondance logique
- Ajout de vNICs multiples aux VM
- Répartition des flux
================================ #>

Add-VMNetworkAdapter -VMName "VM-Test01" -SwitchName "vSwitch-Production" -Name "vNIC-Prod"
Add-VMNetworkAdapter -VMName "VM-Test01" -SwitchName "vSwitch-Gestion" -Name "vNIC-Gestion"

# Suppression de l’interface de gestion par défaut:
Remove-VMNetworkAdapter -ManagementOS -Name "vEthernet"
