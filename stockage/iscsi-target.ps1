<#
.SYNOPSIS
    Configuration iSCSI pour un cluster Hyper-V
.DESCRIPTION
    iSCSI (Internet Small Computer System Interface) est un protocole de transport qui encapsule les 
    commandes SCSI sur IP (IPv4 ou IPv6), permettant à un hôte (initiator) d’accéder à un périphérique 
    de stockage distant (target) comme s’il s’agissait d’un disque local.
.LINK
    https://woshub.com/configure-iscsi-traget-and-initiator-windows-server/
#>

Install-WindowsFeature -Name FS-iSCSITarget-Server

# Vérification de l’espace disque disponible:
Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" | 
Select-Object DeviceID, @{
    Name="FreeSpace(GB)"
    Expression={"{0:N2}" -f ($_.FreeSpace/1GB)}
}

$IscsiVirtualDisk = @{
    Path = "C:\iSCSIVirtualDisks\iSCSIVirtualDisk01.vhdx"
    Size = 40GB
    UsedFixed = $true
    ErrorAction = "Stop"
}
$TargetName = "ISCSI"
try {
    New-IscsiVirtualDisk @IscsiVirtualDisk
    New-IscsiServerTarget -TargetName $TargetName -InitiatorIds @(
    "IPAddress:192.168.1.10"
    "IPv6Address:</à compléter/>"
    )
    Add-IscsiVirtualDiskTargetMapping -TargetName $TargetName -Path "C:\iSCSIVirtualDisks\iscsiDisk.vhdx"     
}
catch {
    $PSItem.Exception.Message
    $PSItem.Exception.Source
    $PSItem.Exception.TargetSite
    $PSItem.ScriptStackTrace
    $PSItem.ErrorDetails.Message
}

# Vérification:
Get-IscsiServerTarget | ForEach-Object {
    $_.LunMappings | Format-List
}







