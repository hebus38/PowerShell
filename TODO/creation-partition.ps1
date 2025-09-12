<#
.SYNOPSIS
Crée une partition dédiée au stockage des machines virtuelles sur un hôte Hyper-V Core.

.DESCRIPTION
Ce script interactif détecte l’espace libre sur le disque système, propose une taille et une lettre de lecteur,
crée une partition NTFS et prépare un dossier "VMs" pour héberger les fichiers .vhdx.

.LINK
https://learn.microsoft.com/en-us/powershell/module/storage/new-partition
https://learn.microsoft.com/en-us/powershell/module/storage/get-partition
#>

# Identification du disque système:
$disk = Get-Disk | 
Where-Object IsSystem -eq $true | 
Format-List

# Calcul de l’espace disque disponible:
$sizeInfo = Get-PartitionSupportedSize -DiskNumber $disk.Number -PartitionNumber 0
$freeSpaceGB = [math]::Round($sizeInfo.SizeMax / 1GB, 2)
Write-Host "💽 Espace libre disponible sur le disque système : $freeSpaceGB Go"

# === SAISIE UTILISATEUR ===
$sizeGB = Read-Host "👉 Taille de la partition à créer (en Go, max $freeSpaceGB)"
if ($sizeGB -gt $freeSpaceGB) {
    Write-Host "❌ Taille trop grande. Abandon." -ForegroundColor Red
    return
}

$driveLetter = Read-Host "👉 Lettre à assigner à la partition (ex: V)"

# === SPLATTING POUR New-Partition ===
$partitionParams = @{
    DiskNumber        = $disk.Number
    Size              = ($sizeGB * 1GB)
    AssignDriveLetter = $true
}

$partition = New-Partition @partitionParams

# === SPLATTING POUR Format-Volume ===
$formatParams = @{
    Partition           = $partition
    FileSystem          = "NTFS"
    NewFileSystemLabel  = "VMStorage"
    Confirm             = $false
}

Format-Volume @formatParams

# === ASSIGNATION DE LA LETTRE ===
Set-Partition -DriveLetter $partition.DriveLetter -NewDriveLetter $driveLetter

# === CRÉATION DU DOSSIER DE STOCKAGE DES VMs ===
New-Item -Path "$($driveLetter):\VMs" -ItemType Directory -Force

Write-Host "`n✅ Partition '$driveLetter:' créée avec $sizeGB Go pour héberger les VMs"
Write-Host "📁 Dossier de stockage : $($driveLetter):\VMs"
