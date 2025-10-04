$ReplicaServer = "SRV-HYP-2"
Write-Progress -Activity "Configuration de ${ReplicaServer}" `
    -Status "Activation d'Hyper-V Replica..."

Invoke-Command -VMName $ReplicaServer -Credential $Creds -ScriptBlock {
    try {
        #$server = "SRV-HYP-2"
        $cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=SRV-HYP-2 - Test 4" }
        $thumbprint = $cert.Thumbprint

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

