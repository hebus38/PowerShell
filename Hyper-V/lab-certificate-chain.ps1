$ReplicaServer = "SRV-HYP-2"
Write-Progress -Activity "Configuration de ${ReplicaServer}" `
    -Status "Génération d’une chaîne de certificats..." 
Invoke-Command -VMName $ReplicaServer -Credential $Creds -ScriptBlock {
    try {
        $server = "SRV-HYP-2"
        $folder = "C:\CRL"

        Write-Host "`nCréation d’un certificat racine..." -ForegroundColor Cyan
        $params = @{
            Type = 'Custom' 
            Subject = 'CN=SRV-HYP-2 Root CA'
            TextExtension = @('2.5.29.19={text}CA=true')
            FriendlyName = "Certificat racine de SRV-HYP-2"
            KeyUsage = 'CertSign', 'CRLSign', 'DigitalSignature' 
            KeyAlgorithm = 'RSA'
            KeyLength = 2048
            CertStoreLocation = "Cert:\LocalMachine\My"
        }
        $ca = New-SelfSignedCertificate @params -ErrorAction Stop
        Start-Sleep -Seconds 2

        Write-Host "`nExportation du certificat racine..."
        Export-Certificate -Cert $ca -FilePath $("{0}\local-root-ca.cer" -f $folder) -ErrorAction Stop
        Start-Sleep -Seconds 3
        
        Write-Host "`nAjout du certificat au magasin racine (Root)..." -ForegroundColor Cyan
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
            FriendlyName = "Certificat d’authentification SRV-HYP-2"
            Signer = $ca
            TextExtension = @(
                '2.5.29.19={text}CA=false',
                '2.5.29.31={text}http://localhost/crl.crl'
            )
            CertStoreLocation = "Cert:\LocalMachine\My"
        }    
        $cert = New-SelfSignedCertificate @params -ErrorAction Stop           
        start-sleep -Seconds 3
        $thumbprint = $cert.Thumbprint
        Write-Host "`nEmpreinte du certificat:" -ForegroundColor Cyan
        $thumbprint
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