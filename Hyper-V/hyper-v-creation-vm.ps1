<#
  .SYNOPSIS
    Crée une machine virtuelle sur un hôte Hyper-V distant et prépare son installation en tant que contrôleur de domaine.

  .DESCRIPTION
    Ce script PowerShell utilise le splatting pour créer une VM sur un hôte Hyper-V distant, copier un disque VHDX de référence,
    injecter un fichier Unattend.xml, et démarrer la VM. Il est conçu pour automatiser le déploiement d’un contrôleur de domaine
    dans un environnement Workgroup ou lab.

    Le script doit être exécuté avec des droits administrateur et nécessite que les partages réseau soient accessibles depuis la machine locale.

  .LINK
    https://github.com/doctordns/ReskitBuildScripts
    https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_splatting?view=powershell-7.5
    https://learn.microsoft.com/en-us/powershell/scripting/samples/working-with-registry-entries?view=powershell-7.5

  .EXAMPLE
    .\Create-DCVM.ps1

    Crée une VM nommée "DC1" sur l’hôte "SRVHYPERV", copie le VHDX de référence, injecte le fichier Unattend.xml,
    et démarre la VM pour lancer l’installation automatisée du contrôleur de domaine.

  .NOTES
    Un dossier partagé (D:\VMs, D:\Reference, D:\Unattend)

    Le fichier ISO de Windows Server monté dans un VHDX via New-ReferenceVHDX.ps1

    Un fichier UnattendDC.xml adapté pour installer et promouvoir le serveur en tant que DC
  #>

# Paramètres principaux
<#
-Name $Name 
-MemoryStartupBytes 4GB 
-Generation 2 
-Path "D:\Hyper-V" 
-NewVHDPath "D:\Hyper-V\$Name\Virtual Hard Disks\$Name.vhdx" 
-NewVHDSizeBytes 64GB 
-SwitchName "LAN-Physique"
*************************
[[-Name] <String>]
    [[-MemoryStartupBytes] <Int64>]
    [[-Generation] <Int16>]
    [-BootDevice <BootDevice>]
    [-NoVHD]
    [-SwitchName <String>]
    [-Path <String>]
    [-SourceGuestStatePath <String>]
    [-Version <Version>]
    [-Prerelease]
    [-Experimental]
    [-GuestStateIsolationType <GuestIsolationType>]
    [-Force]
    [-AsJob]
    [-CimSession <CimSession[]>]
    [-ComputerName <String[]>]
    [-Credential <PSCredential[]>]
    [-WhatIf]
    [-Confirm]
    [<CommonParameters>]
#>
$name = "DC1"
$memoryStartupBytes = "4 GB"
$generation = "2"
$host        = "SRVHYPERV"
$swith = "EXT-vSwitch"

$VMPath        = "\\$VMHost\D$\VMs\$VMName"
$VHDXTemplate  = "\\$VMHost\D$\Reference\WS2022.vhdx"
$VHDXPath      = "$VMPath\$VMName.vhdx"


$UnattendFile  = "\\$VMHost\D$\Unattend\UnattendDC.xml"

# Splatting pour la copie du VHDX
$copyParams = @{
    Path        = $VHDXTemplate
    Destination = $VHDXPath
}
Copy-Item @copyParams

# Splatting pour la création de la VM sur l’hôte distant
$vmCreationParams = @{
    VMName        = $VMName
    VMPath        = $VMPath
    VHDXPath      = $VHDXPath
    SwitchName    = $SwitchName
    MemoryStartup = $MemoryStartup
}

Invoke-Command -ComputerName $VMHost -ScriptBlock {
    param($params)

    $newVMParams = @{
        Name               = $params.VMName
        MemoryStartupBytes = $params.MemoryStartup
        Generation         = 2
        Path               = $params.VMPath
        SwitchName         = $params.SwitchName
    }
    New-VM @newVMParams

    Set-VMFirmware -VMName $params.VMName -EnableSecureBoot Off

    $diskParams = @{
        VMName = $params.VMName
        Path   = $params.VHDXPath
    }
    Add-VMHardDiskDrive @diskParams
} -ArgumentList $vmCreationParams

# Splatting pour l’injection du fichier Unattend.xml
$unattendParams = @{
    VHDXPath     = $VHDXPath
    UnattendFile = $UnattendFile
}

Invoke-Command -ComputerName $VMHost -ScriptBlock {
    param($params)

    $mountParams = @{
        Path    = $params.VHDXPath
        Passthru = $true
    }
    $disk = Mount-VHD @mountParams
    $vol = ($disk | Get-Disk | Get-Partition | Get-Volume)[0]

    $copyUnattendParams = @{
        Path        = $params.UnattendFile
        Destination = "$($vol.DriveLetter):\Windows\Panther\Unattend.xml"
    }
    Copy-Item @copyUnattendParams

    Dismount-VHD -Path $params.VHDXPath
} -ArgumentList $unattendParams

# Splatting pour le démarrage de la VM
$startParams = @{
    VMName = $VMName
}

Invoke-Command -ComputerName $VMHost -ScriptBlock {
    param($params)
    Start-VM -Name $params.VMName
} -ArgumentList $startParams

Write-Host "✅ La VM '$VMName' est créée et en cours d'installation sur '$VMHost'."
