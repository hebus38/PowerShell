<#
.SYNOPSIS

    Mise en oeuvre de Hyper-V Replica.

.DESCRIPTION

    Hyper-V Replica fournit la réplique d’une VM exécutée sur un hôte Hyper-V pouvant être stockée et 
    mise à jour sur un autre hôte Hyper-V. La réplication est asynchrone (lagged copy) et aucun stockage 
    partagé n’est nécessaire.
    =
    RPO (Recovery Point Objective): Hyper-V Replica effectue une réplication initiale complète du disque 
    virtuel. Le différentiel des modifications est transmit à intervalles réguliers (30s par défaut). 
    
    RTO (Recovery Time Objective): basculement manuel de la VM répliquée sur le serveur 'replica', càd le
    serveur cible.
    =
    L’objectif est d’évaluer la fonctionnalité de réplication et d’éffectuer un basculement manuel 
    (failover) d’une VM entre deux hôtes Hyper-V. Les deux hôtes Hyper-V sont des machines virtuelles,
    d’où l’activation de la virtualisation imbriquée.
    
    Ce script illustre les étapes de configuration d’Hyper-V Replica sur le serveur replica; "SRV-HYP-2". 

.LINK
    https://microsoftlearning.github.io/AZ-801-Configuring-Windows-Server-Hybrid-Advanced-Services/Instructions/Labs/LAB_04_Implementing_Hyper-V_Replica_and_Windows_Server_Backup.html
    https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/manage/set-up-hyper-v-replica

.NOTES
    Il y a quelques incohérences dans le lab en lien ci-dessus.    
#>
###
# INITIALISATION:
##
$Psswrd = ConvertTo-SecureString "motDEpasse_1" -AsPlainText -Force
$Crdntl = New-Object System.Management.Automation.PSCredential ("$SRV\Administrateur", $Psswrd)

$SRV = "SRV-HYP-2"

# Vérification de l’activation de la virtualisation imbriquée pour le serveur cible :
Invoke-Command -VMName $SRV -Credential $Crdntl -ScriptBlock {
    Get-CimInstance -ClassName Win32_Processor | 
    Select-Object VirtualizationFirmwareEnabled |
    Format-List
}
# Activation de l’extension de virtualisation imbriquée (le serveur doit être arrêté): 
Set-VMProcessor -VMName $ReplicaServer -ExposeVirtualizationExtensions $true

##
# PRÉ-REQUIS:
##
Invoke-Command -VMName $SRV -Credential $Crdntl -ScriptBlock {
    try {
        $folder = Test-Path -Path "C:\ReplicaStorage"    
        if (-not $folder) {
            Write-Host "`nCréation du dossier de migration:" -ForegroundColor Yellow
            New-Item -ItemType Directory -Path "C:\ReplicaStorage" -Force
            Write-Host "`n"
            Start-Sleep -Seconds 2
        }
        $hvFeature = Get-WindowsFeature -Name Hyper-V -ErrorAction Stop
        if (-not $hvFeature.Installed) {
            Write-Host "Installation du rôle Hyper-V:`n" -ForegroundColor Yellow
            Install-WindowsFeature -Name Hyper-V -IncludeManagementTools `
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
    $property = @(
        'Name',
        'DisplayName', 
        'DisplayGroup', 
        'Direction', 
        'Enabled'
    )
    Get-NetFirewallRule  | 
    Where-Object { $_.DisplayName -match "\bHTTP\b.*réplica"} | 
    Select-Object -Property $property 
}

Invoke-Command -VMName $SRV -Credential $Crdntl -ScriptBlock {
    $rule = "VIRT-HVRHTTPL-In-TCP-NoScope"
    Enable-NetFirewallRule -Name $rule
}
###
# CONFIGURATION DE HYPER-V REPLICA:
##
try {
    Invoke-Command -VMName $SRV -Credential $Crdntl -ScriptBlock {
        try {
            $params = @{
                ReplicationEnabled = $true
                AllowedAuthenticationType = 'Kerberos' 
                KerberosAuthenticationPort = 8080 
                ReplicationAllowedFromAnyServer = $true 
                DefaultStorageLocation = 'C:\ReplicaStorage'
            }
            "`n"
            Write-Progress -Activity "Configuration de Hyper-V Replica:"
            Set-VMReplicationServer @params -ErrorAction Stop
            Start-Sleep -Seconds 3
            Get-VMReplicationServer | Format-List
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


    