<#
EXT-vSwitch-Mgmt	    Externe	IPv4/IPv6	Accès web, SMB, RDP
EXT-vSwitch-iSCSI	    Externe dédié	    IPv4/IPv6	Accès aux cibles iSCSI
INT-vSwitch-Lab 		IPv4 only	        Communication intra-lab
#>

# SRV-HYP-1:
Get-VMNetworkAdapter -VMName "SRV-HYP-1" | Where-Object -Property Name -EQ "vNIC-Management" | 
Connect-VMNetworkAdapter -SwitchName "EXT-vSwitch"

Get-VMNetworkAdapter -VMName "SRV-HYP-1" | Where-Object -Property Name -EQ "vNIC-Storage" | 
Connect-VMNetworkAdapter -SwitchName "EXT-vSwitch"

<# NAT:
New-VMSwitch -SwitchName "vNAT" -SwitchType Internal
New-NetIPAddress -IPAddress 192.168.200.1 -PrefixLength 24 -InterfaceAlias "vEthernet (vNAT)"
New-NetNat -Name "vNATNetwork" -InternalIPInterfaceAddressPrefix "192.168.200.0/24"
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










New-VMSwitch -Name "EXT-vSwitch-iSCSI" -NetAdapterName "NIC-iSCSI" -AllowManagementOS $false
Add-VMNetworkAdapter -VMName "SRV-HV1" -Name "vNIC-iSCSI" -SwitchName "EXT-vSwitch-iSCSI"

New-NetIPAddress -InterfaceAlias "vNIC-iSCSI" -IPAddress "192.168.100.10" -PrefixLength 24 -DefaultGateway "192.168.100.1"
New-NetIPAddress -InterfaceAlias "vNIC-iSCSI" -IPAddress "fd00:100::10" -PrefixLength 64 -DefaultGateway "fd00:100::1"


