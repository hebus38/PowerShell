Configuration BuildHyperVCluster {

    param (
        [string[]]$NodeName = @("SRV-HV1", "SRV-HV2")
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xHyper-V
    Import-DscResource -ModuleName xNetworking

    Node $NodeName {

        # Étape 1 : Installation des rôles Hyper-V et Cluster
        WindowsFeature HyperV {
            Name = "Hyper-V"
            Ensure = "Present"
        }

        WindowsFeature FailoverClustering {
            Name = "Failover-Clustering"
            Ensure = "Present"
        }

        WindowsFeature HyperVTools {
            Name = "Hyper-V-Tools"
            Ensure = "Present"
            DependsOn = "[WindowsFeature]HyperV"
        }

        WindowsFeature HyperVPS {
            Name = "Hyper-V-PowerShell"
            Ensure = "Present"
            DependsOn = "[WindowsFeature]HyperV"
        }

        # Étape 2 : Renommage des interfaces réseau
        xNetAdapterName NICGestion {
            InterfaceAlias = "Ethernet"
            NewName = "NIC-Gestion"
        }

        xNetAdapterName NICProduction {
            InterfaceAlias = "Ethernet 2"
            NewName = "NIC-Production"
        }

        # Étape 3 : Configuration IP statique
        xIPAddress GestionIP {
            IPAddress      = "10.0.10.11"
            InterfaceAlias = "NIC-Gestion"
            SubnetMask     = "255.255.255.0"
            AddressFamily  = "IPv4"
        }

        xIPAddress ProductionIP {
            IPAddress      = "10.0.40.11"
            InterfaceAlias = "NIC-Production"
            SubnetMask     = "255.255.255.0"
            AddressFamily  = "IPv4"
            DefaultGateway = "10.0.40.1"
        }

        # Étape 4 : Création du vSwitch SET
        xVMSwitch vSwitchSET {
            Name                  = "vSwitch-SET"
            NetAdapterName        = @("NIC-Gestion", "NIC-Production")
            EnableEmbeddedTeaming = $true
            Ensure                = "Present"
        }

        # Étape 5 : Activation de SMB Multichannel
        Script EnableSMBMultichannel {
            GetScript = {
                @{ Result = (Get-SmbServerConfiguration).EnableSMBMultichannel }
            }
            SetScript = {
                Set-SmbServerConfiguration -EnableSMBMultichannel $true
            }
            TestScript = {
                (Get-SmbServerConfiguration).EnableSMBMultichannel -eq $true
            }
            DependsOn = "[WindowsFeature]FailoverClustering"
        }

        # Étape 6 : Création des vNICs sur l’OS hôte
        Script CreateVNICs {
            GetScript = { @{ Result = "vNICs checked" } }
            SetScript = {
                Add-VMNetworkAdapter -ManagementOS -Name "vNIC-Management" -SwitchName "vSwitch-SET"
                Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "vNIC-Management" -Access -VlanId 10

                Add-VMNetworkAdapter -ManagementOS -Name "vNIC-Cluster" -SwitchName "vSwitch-SET"
                Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "vNIC-Cluster" -Access -VlanId 20

                Add-VMNetworkAdapter -ManagementOS -Name "vNIC-Migration" -SwitchName "vSwitch-SET"
                Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "vNIC-Migration" -Access -VlanId 30

                Add-VMNetworkAdapter -ManagementOS -Name "vNIC-Storage" -SwitchName "vSwitch-SET"
                Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "vNIC-Storage" -Access -VlanId 50
            }
            TestScript = {
                $adapters = Get-VMNetworkAdapter -ManagementOS
                $adapters.Name -contains "vNIC-Management" -and
                $adapters.Name -contains "vNIC-Cluster" -and
                $adapters.Name -contains "vNIC-Migration" -and
                $adapters.Name -contains "vNIC-Storage"
            }
            DependsOn = "[xVMSwitch]vSwitchSET"
        }

        # Étape 7 : Préparation du stockage CSV (à compléter selon ton SAN/NAS)
        Script PrepareStorage {
            GetScript = { @{ Result = "Storage checked" } }
            SetScript = {
                $disks = Get-ClusterAvailableDisk
                if ($disks) {
                    $disks | Add-ClusterDisk
                    Add-ClusterSharedVolume -Name $disks[0].Name
                }
            }
            TestScript = {
                (Get-ClusterSharedVolume).Count -ge 1
            }
            DependsOn = "[WindowsFeature]FailoverClustering"
        }
    }
}
# Exemple d'appel de la configuration
BuildHyperVCluster -NodeName "SRV-HV1","SRV-HV2"
Start-DscConfiguration -Path .\BuildHyperVCluster -Wait -Verbose -Force
