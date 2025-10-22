Test-Cluster -Node "SRV-HYP-1","SRV-HYP-2" `
             -Include "Inventory","Network","System Configuration","Storage" `
             -Verbose

New-Cluster -Name "CL-AUBENAS" `
            -Node "SRV-HYP-1","SRV-HYP-2" `
            -StaticAddress "10.10.10.10" `
            -NoStorage `
            -AdministrativeAccessPoint "DNS"
# Vérification des réseaux détectés
Get-ClusterNetwork | Format-Table Name, Address, Role

# Attribution des rôles réseau
(Get-ClusterNetwork -Name "NVC-HeartBeat").Role = 1      # VLAN 99
(Get-ClusterNetwork -Name "NVC-Migration").Role = 1      # VLAN dédié
(Get-ClusterNetwork -Name "NVC-Management").Role = 3     # VLAN 10

# Exclusion des réseaux non dédiés à la migration
$excluded = Get-ClusterNetwork | Where-Object { $_.Name -ne "NVC-Migration" } | Select-Object -ExpandProperty ID
Set-ClusterParameter -Name MigrationExcludeNetworks -Value ($excluded -join ";")

# Activation VMQ sur l’interface de migration
Set-NetAdapterAdvancedProperty -Name "vEthernet (NVC-Migration)" `
                               -DisplayName "Virtual Machine Queue" `
                               -DisplayValue "Enabled"

# Attribution de poids de bande passante
Set-VMNetworkAdapter -ManagementOS -Name "NVC-Migration" -MinimumBandwidthWeight 50
Set-VMNetworkAdapter -ManagementOS -Name "NVC-HeartBeat" -MinimumBandwidthWeight 10

# Depuis SRV-HYP-2 (réplica)
Start-VMFailover -VMName "TestMIG" -ComputerName "SRV-HYP-2"
Set-VMReplication -Reverse -VMName "TestMIG" -ComputerName "SRV-HYP-2"
Start-VM -VMName "TestMIG" -ComputerName "SRV-HYP-2"

# État du cluster
Get-ClusterNode
Get-ClusterGroup
Get-ClusterNetwork

# Journal PRA
Get-ClusterLog -Destination "C:\ClusterLogs" -UseLocalTime
