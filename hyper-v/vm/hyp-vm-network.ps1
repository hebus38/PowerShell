<#
.SYNOPSIS
    Configuration réseau des VMs Hyper-V pour migration.
#>
$Psswrd = ConvertTo-SecureString "motDEpasse_1" -AsPlainText -Force
$Crdntl = New-Object System.Management.Automation.PSCredential ("SRV-HYP-1\Administrateur", $Psswrd)
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
            Set-DnsClientServerAddress -InterfaceAlias $Alias -ServerAddresses "10.0.30.10"
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

