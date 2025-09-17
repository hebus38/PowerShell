<#
.DESCRIPTION
Simulation d’un cluster à basculement Hyper-V avec 2 hôtes Hyper-V (noeuds). L'objectif est de fournir de la haute disponibilité pour les machines virtuelles (VMs).
Les machines virtuelles sont stockées dans un espace de stockage partagé, situé sur un NAS, qui joue le rôle de cible iSCSI.

| Éléments simulés       | Réalité physique | lab                             |
|------------------------+------------------+---------------------------------|
| 2 hôtes Hyper-V        | 2 serveurs       | 2 VMs (SRV-HV1, SRV-HV2)        |
| Cartes réseau séparées | 2 NICs par hôte  | vNICs internes                  |
| VLANs                  | Switch physique  | vSwitch + tagging               |
| Stockage partagé       | SAN/NAS          | VHD monté en iSCSI ou CSV local |
#>

$computerName = $env:COMPUTERNAME
$os = Get-CimInstance win32_operatingsystem -Property TotalVisibleMemorySize,FreePhysicalMemory -Computername $computerName
$inUseMemory = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1kB

Write-Host "Mémoire utilisée : $([math]::Round($inUseMemory/1GB,2)) GB"

# ÉTAPE 1 : Création du vSwitch interne pour le lab
New-VMSwitch -Name "INT-vSwitch-Lab" -SwitchType Internal

<# ============================================
ÉTAPE 3 : Configuration réseau dans les VMs
- IP statiques sur chaque vNIC
- Simulation des VLANs si besoin
============================================ #>

# À faire dans chaque VM (SRV-HV1 et SRV-HV2) via PowerShell distant ou console :
# Exemple dans SRV-HV1 :
New-NetIPAddress -InterfaceAlias "vNIC-Management" -IPAddress 10.0.10.11 -PrefixLength 24
    New-NetIPAddress -InterfaceAlias "vNIC-Cluster"    -IPAddress 10.0.20.11 -PrefixLength 24
New-NetIPAddress -InterfaceAlias "vNIC-Migration"  -IPAddress 10.0.30.11 -PrefixLength 24
New-NetIPAddress -InterfaceAlias "vNIC-Storage"    -IPAddress 10.0.50.11 -PrefixLength 24
New-NetIPAddress -InterfaceAlias "vNIC-VM"         -IPAddress 10.0.40.11 -PrefixLength 24

<# ============================================
ÉTAPE 4 : Installation des rôles dans les VMs
- Hyper-V (optionnel si nested)
- Cluster de basculement
============================================ #>

# Dans SRV-HV1 et SRV-HV2
Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools

<# ============================================
ÉTAPE 5 : Création du cluster simulé
- Nom : Cluster-Lab
- IP virtuelle sur réseau Management
============================================ #>

New-Cluster -Name "Cluster-Lab" -Node "SRV-HV1","SRV-HV2" -StaticAddress 10.0.10.100
Test-Cluster -Node "SRV-HV1","SRV-HV2"
