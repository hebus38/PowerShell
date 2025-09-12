<#
.SYNOPSIS
Crée une machine virtuelle Hyper-V complète sur un hôte distant, avec stockage réseau SMB.

.DESCRIPTION
Ce script crée une VM nommée "VM01" sur un hôte Hyper-V distant, génère un disque dur virtuel (.vhdx)
et stocke tous les fichiers VM sur un partage réseau SMB (ex: Freebox, NAS). Il utilise PowerShell Remoting.

.LINK
https://learn.microsoft.com/en-us/powershell/module/hyper-v/new-vm
#>

# === PARAMÈTRES ===
$vmName        = "VM01"
$vmMemory      = 1GB
$vmDiskSize    = 40GB
$vmShareRoot   = "\\192.168.1.254\VMs"              # Partage SMB
$vmStoragePath = "$vmShareRoot\$vmName"             # Dossier VM sur le réseau
$vmDiskPath    = "$vmStoragePath\$vmName.vhdx"      # Disque virtuel sur le réseau
$vmHost        = "SRVHYPERV"
$vmCred        = Get-Credential

# === CRÉATION DU DOSSIER DE STOCKAGE SUR LE PARTAGE SMB ===
Invoke-Command -ComputerName $vmHost -Credential $vmCred -ScriptBlock {
    param($path)
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force
    }
} -ArgumentList $vmStoragePath

# === CRÉATION DU DISQUE VHDX SUR LE PARTAGE SMB ===
Invoke-Command -ComputerName $vmHost -Credential $vmCred -ScriptBlock {
    param($vhdPath, $size)
    New-VHD -Path $vhdPath -SizeBytes $size -Dynamic
} -ArgumentList $vmDiskPath, $vmDiskSize

# === CRÉATION DE LA VM SUR L’HÔTE DISTANT ===
$vmParams = @{
    Name               = $vmName
    MemoryStartupBytes = $vmMemory
    VHDPath            = $vmDiskPath
    Generation         = 2
    Path               = $vmStoragePath
    ComputerName       = $vmHost
    Credential         = $vmCred
}

New-VM @vmParams
