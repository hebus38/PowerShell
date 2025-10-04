<#
.SYNOPSIS
    Mettre en oeuvre la haute disponibilité pour machines virtuelles hébergées sur un hôte Hyper-V.

.DESCRIPTION
    Il existe plusieurs méthodes de tolérantes de pannes et de résilience pour machines virtuelles hébergées sur un hôte Hyper-V. 
    
    Hyper-V Replica fournit la réplique d’une VM exécutée sur un hôte Hyper-V pouvant être stockée et mise à jour sur un autre hôte Hyper-V. 
    La réplication est asynchrone (lagged copy) et aucun stockage partagé n’est nécessaire.
    
    RPO (Recovery Point Objective): Hyper-V Replica effectue une réplication initiale complète du disque virtuel. 
    Le différentiel des modifications est transmit à intervalles réguliers (30s par défaut). 
    
    Les points de récupération (horaire) sont optionnels et créés à partir des blocs modifiés, avec impact sur les ressources. 

    RTO (Recovery Time Objective): basculement manuel de la VM répliquée sur le serveur de réplica.


    Ce script illustre les étapes de configuration d’Hyper-V Replica et simule deux noeuds Hyper-V, "SRV-HYP-1" et "SRV-HYP-2".  

.NOTES
    Invoke-Command -FilePath ".\mon-script.ps1" -ComputerName "LAB-HYPERV" -Credential "LAB-HYPERV\Administrateur"
    
.LINK
    https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/manage/set-up-hyper-v-replica
#>

####
## Configuration d’Hyper-V Replica sur les deux hôtes Hyper-V:
###

# Configuration du serveur replica SRV-HYP-2 (cible):
$ReplicaServer = "SRV-HYP-2"

# Activation de l’extension de virtualisation imbriquée pour le serveur cible (doit être arrêté): 
Set-VMProcessor -VMName $ReplicaServer -ExposeVirtualizationExtensions $true

# Vérification de l’activation de la virtualisation imbriquée pour le serveur cible :
Invoke-Command -VMName $ReplicaServer -Credential $Creds -ScriptBlock {
    Get-CimInstance -ClassName Win32_Processor | 
        Select-Object VirtualizationFirmwareEnabled
}    

# Vérification des prérequis pour Hyper-V Replica:
Write-Progress -Activity "Configuration de ${ReplicaServer}" `
    -Status "Vérification de prérequis..."
try {
    Invoke-Command -VMName $ReplicaServer -Credential $Creds -ScriptBlock {
        $folder = Test-Path -Path "C:\ReplicaStorage"    
        if (-not $folder) {
            Write-Host "Création du dossier de migration..." -ForegroundColor Cyan
            New-Item -ItemType Directory -Path "C:\ReplicaStorage" -Force
            Write-Host "`n"
        }
        $hvFeature = Get-WindowsFeature -Name Hyper-V -ErrorAction Stop
        if (-not $hvFeature.Installed) {
            Write-Host "Installation du rôle Hyper-V..." -ForegroundColor Cyan
            Install-WindowsFeature -Name Hyper-V -IncludeManagementTools `
                -ErrorAction Stop `
                -Restart
            start-sleep -Seconds 3
        }
    }
}    
catch {
    "`n"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    "`n"
}
#####    
Write-Progress -Activity "Configuration de ${ReplicaServer}" `
    -Status "Activation d'Hyper-V Replica..."
try {
    Invoke-Command -VMName $ReplicaServer -Credential $Creds -ScriptBlock {
        try {
            $server = "SRV-HYP-2"
            # Désactivation de la vérification CRL:
            #certutil -setreg chain\EnableRevocationCheck 0

            write-Host "`nGénération d’une chaîne de certificats pour notre serveur..." -ForegroundColor Cyan

            Write-Host "`nCréation d’un certificat racine..." -ForegroundColor Cyan
            $params = @{
                Type = 'Custom' 
                Subject = 'CN=SRV-HYP-2-Certificat-d-Autorité'
                TextExtension = @('2.5.29.19={text}CA=true')
                FriendlyName = "Certificat d’autorité SRV-HYP-2"
                KeyUsage = 'CertSign', 'CRLSign', 'DigitalSignature' 
                KeyAlgorithm = 'RSA'
                KeyLength = 2048
                CertStoreLocation = "Cert:\LocalMachine\My"
            }
            $ca = New-SelfSignedCertificate @params
            Start-Sleep -Seconds 2

            Write-Host "`nAjout du certificat au magasin 'Root'" -ForegroundColor Cyan
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
            $store.Open("ReadWrite")
            $store.Add($ca)
            $store.Close()
            Start-Sleep -Seconds 2

            Write-Host "`nCréation d’un certificat d’authentification pour ${server}..." -ForegroundColor Cyan
            $params = @{
                Type = 'Custom'
                Subject = 'CN=SRV-HYP-2'
                DnsName = 'SRV-HYP-2'
                KeyUsage = 'DigitalSignature'
                FriendlyName = "Certificat d’authentification de SRV-HYP-2"
                Signer = $ca
                CertStoreLocation = "Cert:\LocalMachine\My"
            }    
            $cert = New-SelfSignedCertificate @params            
            #$cert.Verify()

            start-sleep -Seconds 3

            $thumbprint = $cert.Thumbprint
            Write-Host "`nEmpreinte du certificat:" -ForegroundColor Cyan
            $thumbprint
        
            Write-Host "`nConfiguration d'Hyper-V Replica..." -ForegroundColor Cyan
            Set-VMReplicationServer -ReplicationEnabled $true `
                -AllowedAuthenticationType Certificate `
                -CertificateThumbprint $thumbprint `
                -DefaultStorageLocation "C:\ReplicaStorage" `
                -ReplicationAllowedFromAnyServer $true `
                #-ErrorAction Stop
            start-sleep -Seconds 3

            Write-Host "`nConfiguration d'Hyper-V Replica terminée." -ForegroundColor Green
            Get-VMReplicationServer        
        }
        catch {
            "`n"
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-Host $_.ScriptStackTrace -ForegroundColor Red
            Write-Host $_.ErrorDetails.Message -ForegroundColor Red    
            Write-Host $_.Exception.InnerException -ForegroundColor Red
            "`n"
        }
    }
}
catch {
    "`n"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    Write-Host $_.ErrorDetails.Message -ForegroundColor Red    
    Write-Host $_.Exception.InnerException -ForegroundColor Red
    "`n"
}
    
