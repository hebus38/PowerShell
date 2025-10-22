<#
.SYNOPSIS

    Mise en oeuvre de Hyper-V Replica.

.DESCRIPTION

    Hyper-V Replica fournit la réplique d’une VM exécutée sur un hôte Hyper-V (serveur primaire) pouvant 
    être stockée et mise à jour sur un autre hôte Hyper-V (serveur replica). La réplication est asynchrone
    (lagged copy) et aucun stockage partagé n’est nécessaire.
    =
    RPO (Recovery Point Objective): Hyper-V Replica effectue une réplication initiale complète du disque 
    virtuel. Le différentiel des modifications est transmit à intervalles réguliers (30s par défaut). 
    
    RTO (Recovery Time Objective): basculement manuel de la VM répliquée depuis le serveur primaire sur 
    le serveur cible.
    =
    L’objectif est d’évaluer la fonctionnalité de réplication et d’éffectuer un basculement manuel 
    (failover) d’une VM entre deux hôtes Hyper-V. Les deux hôtes Hyper-V sont des machines virtuelles,
    d’où l’activation de la virtualisation imbriquée.
    
    Ce script illustre les étapes de configuration d’Hyper-V Replica sur le serveur primaire; "SRV-HYP-1". 

.LINK
    https://microsoftlearning.github.io/AZ-801-Configuring-Windows-Server-Hybrid-Advanced-Services/Instructions/Labs/LAB_04_Implementing_Hyper-V_Replica_and_Windows_Server_Backup.html
    https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/manage/set-up-hyper-v-replica

.NOTES
    Il y a quelques incohérences dans le lab en lien ci-dessus.    
#>
##
# PRÉ-REQUIS:
##
Invoke-Command -VMName $SRV -Credential $Crdntl -ScriptBlock {
    try {
        $hvFeature = Get-WindowsFeature -Name Hyper-V -ErrorAction Stop
        if (-not $hvFeature.Installed) {
            Write-Progress -Activity "Installation du rôle Hyper-V:" 
            Install-WindowsFeature -Name Hyper-V `
            -IncludeManagementTools `
            -ErrorAction Stop `
            -Restart
            Start-Sleep -Seconds 3
        }
    }
    catch {
        "`n"
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        "`n"
    }
}
###    
# PARE-FEU:
###
Invoke-Command -VMName $SRV -Credential $Crdntl -ScriptBlock {
    $rule = Get-NetFirewallRule  | Where-Object { $_.Name -eq "VIRT-HVRHTTPL-In-TCP-NoScope"} | 
    if($rule.Enabled -eq "False"){
        $result = Enable-NetFirewallRule -Name $rule.Name
        #---
        $result.DisplayName
        $result.Enabled
    }
    #Test-NetConnection -ComputerName "SRV-HYP-2" -Port 8080
}
###
# RÉPLICATION:
##
try {
    Invoke-Command -VMName $SRV -Credential $Crdntl -ScriptBlock {
        try {
            $VMName = 'TestMIG'
            $params = @{
                VMName = $VMName
                ReplicaServerName = 'SRV-HYP-2' 
                ReplicaServerPort = 8080
                AuthenticationType = 'Kerberos'
                CompressionEnabled = $true
            }
            "`n"
            Write-Progress -Activity "Activation de Hyper-V Replica:"
            Enable-VMReplication @params -ErrorAction Stop
            Start-Sleep -Seconds 3

            # Start-VMInitialReplication -VMName $VMName 
        }
        catch {
            "`n"
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-Host $_.ScriptStackTrace -ForegroundColor Red

            if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                Write-Host $_.ErrorDetails.Message `
                -ForegroundColor DarkRed    
            }
            "`n"
        }
    } -ErrorAction Stop
}
catch {
    "`n"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    "`n"
}
###
# FAILOVER: A compléter...
##

<#
.DESCRIPTION
    Création d’un cluster Hyper-V
.LINK
    https://learn.microsoft.com/en-us/powershell/module/hyper-v/start-vmfailover?view=windowsserver2025-ps
#>

$VM = 'TestMIG'
$Primary = 'SRV-HYP-1'
$Replica = 'SRV-HYP-2'

Start-VMFailover -Prepare -VMName $VM -ComputerName $Primary
Start-VMFailover -VMName $VM -ComputerName $Replica 

# Inverse la réplication: SRV-HYP-2 devient le nouveau primaire
Set-VMReplication -Reverse -VMName $VM -ComputerName $Replica

Start-VM -VMName $VM -ComputerName $Replica




















