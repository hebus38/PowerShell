$ReplicaServer = "SRV-HYP-2"
Write-Progress -Activity "Configuration de ${ReplicaServer}" `
    -Status "Génération d’une chaîne de certificats..." 
Invoke-Command -VMName $ReplicaServer -Credential $Creds -ScriptBlock {
    try {
        $server = "SRV-HYP-2"
        #$folder = "C:\" - Quel dossier 

        #Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools
        #Install-AdcsCertificationAuthority -CAType StandaloneRootCA -Force

        Write-Host "`nCréation d’un certificat racine..." -ForegroundColor Cyan
        $params = @{
            Type = 'Custom' 
            Subject = 'CN=SRV-HYP-2 Root CA - Test 04'
            TextExtension = @('2.5.29.19={text}CA=true')
            FriendlyName = "Certificat racine de SRV-HYP-2"
            KeyUsage = 'CertSign', 'CRLSign', 'DigitalSignature' 
            KeyAlgorithm = 'RSA'
            KeyLength = 2048
            CertStoreLocation = "Cert:\LocalMachine\My"
        }
        $ca = New-SelfSignedCertificate @params -ErrorAction Stop
        #Start-Sleep -Seconds 2

        Write-Host "`nExportation du certificat racine..." -ForegroundColor Cyan
        #New-Item -ItemType Directory -Path "$folder" 
        Export-Certificate -Cert $ca -FilePath "C:\srv-hyp-2-ca-test-4.cer" -ErrorAction Stop
        #Start-Sleep -Seconds 2
        
        Write-Host "`nAjout du certificat au magasin racine (Root)..." -ForegroundColor Cyan
        #Import-Certificate -FilePath "C:\srv-hyp-2-root-ca.cer" -CertStoreLocation "Cert:\LocalMachine\Root"
        
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
        $store.Open("ReadWrite")
        $store.Add($ca)
        $store.Close()
        #Start-Sleep -Seconds 
        

        Write-Host "`nCréation d’un certificat d’authentification pour ${server}..." -ForegroundColor Cyan
        $params = @{
            Type = 'Custom'
            Subject = 'CN=SRV-HYP-2 - Test 4'
            DnsName = 'SRV-HYP-2'
            KeyUsage = 'DigitalSignature'
            FriendlyName = "Certificat d’authentification SRV-HYP-2"
            Signer = $ca
            CertStoreLocation = "Cert:\LocalMachine\My"
        }    
        $cert = New-SelfSignedCertificate @params -ErrorAction Stop           
        #start-sleep -Seconds 3
        $thumbprint = $cert.Thumbprint
        Write-Host "`nEmpreinte du certificat:" -ForegroundColor Cyan
        $thumbprint

        certutil.exe -crl
        Copy-Item "$env:SystemRoot\System32\CertSrv\CertEnroll\*.crl" "C:\Lab\test.crl" -Force


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