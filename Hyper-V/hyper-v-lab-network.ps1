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

New-VMSwitch -Name "EXT-vSwitch-iSCSI" -NetAdapterName "NIC-iSCSI" -AllowManagementOS $false
Add-VMNetworkAdapter -VMName "SRV-HV1" -Name "vNIC-iSCSI" -SwitchName "EXT-vSwitch-iSCSI"

New-NetIPAddress -InterfaceAlias "vNIC-iSCSI" -IPAddress "192.168.100.10" -PrefixLength 24 -DefaultGateway "192.168.100.1"
New-NetIPAddress -InterfaceAlias "vNIC-iSCSI" -IPAddress "fd00:100::10" -PrefixLength 64 -DefaultGateway "fd00:100::1"


