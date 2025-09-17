<#
.NOTES
2 nœuds Hyper-V (SRV-HV1, SRV-HV2)

2 cartes réseau physiques par nœud : NIC1 et NIC2

Segmentation des flux : gestion, heartbeat, Live Migration, accès VM, stockage

Configuration manuelle


Recoommandations pour le réseau 'heartbeat' du cluster:

Séparer les flux de heartbeat du trafic client
Utiliser des IP statiques sans passerelle ni DNS sur le réseau privé
Désactiver NetBIOS et les protocoles inutiles sur l’interface dédiée au heartbeat
Définir la priorité du réseau de cluster dans la configuration du cluster
Éviter les cartes réseau multiport non indépendantes pour le heartbeat

===
Bonnes pratiques:
Réseau de gestion	Accès administratif aux nœuds	        IP statique, VLAN dédié, supervision activée
Réseau de cluster	Heartbeat + coordination interne	Privé, redondé, sans trafic client
Réseau de migration	Transfert des VM entre nœuds	        Dédié, activé avec SMB Multichannel ou RDMA
Réseau de production	Accès client aux VM	                Segmenté, sécurisé, haute disponibilité
Réseau iSCSI	        Accès au stockage partagé (CSV)	        VLAN isolé, jumbo frames activés
===
Creation d’un cluster de basculement:

Source:
https://learn.microsoft.com/en-us/windows-server/failover-clustering/create-failover-cluster?pivots=powershell

Prérequis (Failover Clustering Hardware Requirements and Storage Options)

Un ensemble de machines identiques ayant les mêmes composants
Une carte réseau dédiée pour les communications réseau et une pour les échanges iSCSI
Des disques séparés (LUNs) configurés au niveau matériel

Installation de la fonctionnalité "Failover Clustering" sur chaque serveur (noeud) du cluster
Vérification de la configuration
Creation du cluster
Ajout d’un disque partagé au cluster
Voir:
https://learn.microsoft.com/en-us/windows-server/failover-clustering/failover-cluster-manage-cluster-shared-volumes?tabs=powershell
Création des roles


#>

# Sur chaque nœud, commence par identifier et renommer les interfaces réseau:
Get-NetAdapter
Rename-NetAdapter -Name "Ethernet" -NewName "NIC-Management"
Rename-NetAdapter -Name "Ethernet 2" -NewName "NIC-Production"

# Configurer les adresses IP statiques pour chaque interface réseau:
# Sur SRV-HV1
New-NetIPAddress -InterfaceAlias "NIC-Management" -IPAddress 192.168.10.11 -PrefixLength #<A DÉFINIR>
Set-DnsClientServerAddress -InterfaceAlias "NIC-Management" -ServerAddresses 192.168.1.254

New-NetIPAddress -InterfaceAlias "NIC-Production" -IPAddress 192.168.20.11 -PrefixLength 24 -DefaultGateway 192.168.1.254
Set-DnsClientServerAddress -InterfaceAlias "NIC-Production" -ServerAddresses 192.168.1.254

# Sur SRV-HV2
New-NetIPAddress -InterfaceAlias "NIC-Management" -IPAddress 192.168.10.12 -PrefixLength #<A DÉFINIR>
Set-DnsClientServerAddress -InterfaceAlias "NIC-Management" -ServerAddresses 192.168.1.254

New-NetIPAddress -InterfaceAlias "NIC-Production" -IPAddress 192.168.20.12 -PrefixLength 24 -DefaultGateway 192.168.1.254
Set-DnsClientServerAddress -InterfaceAlias "NIC-Production" -ServerAddresses 192.168.1.254

# désactiver les services inutiles pour le heartbeat:
Disable-NetAdapterBinding -Name "NIC-Gestion" -ComponentID ms_netbios
Disable-NetAdapterBinding -Name "NIC-Gestion" -ComponentID ms_server

# Création du cluster:
New-Cluster -Name "Cluster-HV" -Node "SRV-HV1","SRV-HV2" -StaticAddress 192.168.10.100
Test-Cluster -Node "SRV-HV1","SRV-HV2"

###
#
###

===
Install-WindowsFeature –Name Failover-Clustering –IncludeManagementTools
Test-Cluster –Node Server1, Server2
New-Cluster -Name CN=MyCluster,OU=Cluster,DC=Contoso,DC=com -Node Server1, Server2 -NoStorage
...(ajout du disque partagé)
Add-ClusterVirtualMachineRole -VirtualMachine "VM-Metier01"
===
New-VM -Name "SRV-HV1" -MemoryStartupBytes 2GB -Generation 2 `
-NewVHDPath "D:\VMs\SRV-HV1\disk.vhdx" -NewVHDSizeBytes 40GB `
-Path "D:\VMs\SRV-HV1"
New-VM -Name "SRV-HV2" -MemoryStartupBytes 2GB -Generation 2 `
-NewVHDPath "D:\VMs\SRV-HV2\disk.vhdx" -NewVHDSizeBytes 40GB `
-Path "D:\VMs\SRV-HV2"

Set-VMProcessor -VMName "SRV-HV1" -ExposeVirtualizationExtensions $true
Set-VMProcessor -VMName "SRV-HV2" -ExposeVirtualizationExtensions $true

Install-WindowsFeature -Name Hyper-V, Failover-Clustering -IncludeManagementTools -Restart

New-Cluster -Name "Cluster-HV" -Node "SRV-HV1","SRV-HV2" -StaticAddress "192.168.100.200"
Test-Cluster -Node "SRV-HV1","SRV-HV2"

Get-ClusterAvailableDisk | Add-ClusterDisk
Add-ClusterSharedVolume -Name "Cluster Disk 1"

New-VM -Name "VM-Test01" -MemoryStartupBytes 512MB -Generation 2 `
-NewVHDPath "C:\ClusterStorage\Volume1\VM-Test01\disk.vhdx" `
-NewVHDSizeBytes 10GB -Path "C:\ClusterStorage\Volume1\VM-Test01"

Add-ClusterVirtualMachineRole -VirtualMachine "VM-Test01"

<#
.DESCRIPTION
Aggrégation de cartes réseau physiques (NIC Teaming) pour la redondance et la répartition de charge

.LINK
https://learn.microsoft.com/en-us/powershell/module/netlbfo/new-netlbfoteam
#>
New-NetLbfoTeam -Name "Team-Production" -TeamMembers "NIC1","NIC2" -TeamingMode SwitchIndependent

<#
Redondance logique au travers de diffèrents chemins réseau virtuels (vNIC, vSwitch, flux SMB) pour répartir les charges et améliorer la résilience 
sans ajouter de matériel. 

Ne protège pas contre une panne physique (ex : carte réseau HS), mais permet :

Une meilleure répartition des flux (Live Migration, CSV, VM)
Une tolérance aux congestions ou interruptions logicielles
Une isolation fonctionnelle des rôles réseau
#>

Add-VMNetworkAdapter -VMName "VM-Test01" -SwitchName "vSwitch-Production" -Name "vNIC-Prod"
Add-VMNetworkAdapter -VMName "VM-Test01" -SwitchName "vSwitch-Gestion" -Name "vNIC-Gestion"

Set-SmbServerConfiguration -EnableSMBMultichannel $true
Get-SmbMultichannelConnection

Get-ClusterNetwork
(Get-ClusterNetwork -Name "Cluster Network 1").Role = 1  # Cluster only (heartbeat)
(Get-ClusterNetwork -Name "Cluster Network 2").Role = 3  # Cluster and client (VM access)

<#
.DESCRIPTION
Segmentation des flux réseau dans un cluster Hyper-V
#>
# Création des vSwitch
New-VMSwitch -Name "vSwitch-Gestion" -NetAdapterName "NIC-Gestion" -AllowManagementOS $false
New-VMSwitch -Name "vSwitch-Prod" -NetAdapterName "NIC-Production" -AllowManagementOS $false

# Ajout des vNICs pour les rôles
Add-VMNetworkAdapter -ManagementOS -Name "vNIC-Management" -SwitchName "vSwitch-Gestion"
Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "vNIC-Management" -Access -VlanId 10

Add-VMNetworkAdapter -ManagementOS -Name "vNIC-Cluster" -SwitchName "vSwitch-Gestion"
Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "vNIC-Cluster" -Access -VlanId 20

Add-VMNetworkAdapter -ManagementOS -Name "vNIC-Migration" -SwitchName "vSwitch-Prod"
Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "vNIC-Migration" -Access -VlanId 30

Add-VMNetworkAdapter -ManagementOS -Name "vNIC-Storage" -SwitchName "vSwitch-Prod"
Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "vNIC-Storage" -Access -VlanId 50
