<#
.SYNOPSIS
Configuration iSCSI pour un cluster Hyper-V

.DESCRIPTION
iSCSI (Internet Small Computer System Interface) est un protocole de transport qui encapsule les commandes 
SCSI sur IP (IPv4 ou IPv6), permettant à un hôte (initiator) d’accéder à un périphérique de stockage 
distant (target) comme s’il s’agissait d’un disque local.

.LINK
https://woshub.com/configure-iscsi-traget-and-initiator-windows-server/
#>

# Vérifier et démarrer le service iSCSI initiator
if ((Get-Service -Name MSiSCSI).Status -ne 'Running') {
    Start-Service MSiSCSI
}
Set-Service MSiSCSI -StartupType Automatic

<# Configuration du pare-feu si nécessaire (port TCP 3260):
$IscsiRules = get-netfirewallservicefilter -Service msiscsi | get-netfirewallrule
if ($IscsiRules.Enabled -eq $false) {
    set-NetFirewallRule -Name "MsiScsi-in-TCP" -Enabled True
    set-NetFirewallRule -Name "MsiScsi-out-TCP" -Enabled True
}
#>

# Ajouter les portails cibles
New-IscsiTargetPortal -TargetPortalAddress "192.168.1.5"
New-IscsiTargetPortal -TargetPortalAddress "2a01:e0a:2db:ad40:5618:d716:1d8d:731d"

# Vérifier la connectivité réseau (ping ou test de port)
Test-NetConnection -ComputerName "192.168.1.5" -Port 3260
Test-NetConnection -ComputerName "2a01:e0a:2db:ad40:5618:d716:1d8d:731d" -Port 3260

# Connexion à la cible si non connectée
$IscsiTarget = Get-IscsiTarget 
if ($IscsiTarget.ConnectionState -ne "Connected") {
    Connect-IscsiTarget -NodeAddress $IscsiTarget.NodeAddress -IsPersistent $true
}

# Initialisation et formatage du disque iSCSI:
Get-Disk | Where-Object -Property PartitionStyle -eq 'RAW' |
Initialize-Disk -PartitionStyle MBR -PassThru |
New-Partition -AssignDriveLetter -UseMaximumSize |
Format-Volume -FileSystem NTFS -Confirm:$false

# Téléchargement de l'ISO d'installation de Windows Server 2025:
$Uri = "https://go.microsoft.com/fwlink/?linkid=2292920&clcid=0x40c&culture=fr-fr&country=fr"
$OutFile = "e:\windows_server_2025.iso"
Invoke-WebRequest -Uri $Uri -OutFile $OutFile