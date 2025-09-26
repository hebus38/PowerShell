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
