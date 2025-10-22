<#
.SYNOPSIS
    Ajout d’une machine au domaine.
#>
$SRV = "SRV-HYP-2"
$Psswrd = Read-Host -AsSecureString "Mot de passe"
$Crdntl = New-Object System.Management.Automation.PSCredential ("$SRV\Administrateur", $Psswrd)

try {
    Invoke-Command -VMName $SRV -Credential $Crdntl -ScriptBlock {
        try {
            $FQDN = "kashyyyk.local"
            $DN = "DC=kashyyyk,DC=local"
            $params = @{
                #ComputerName = "SRV-HYP-2"
                Domain = $FQDN
                OUPath = "OU=Hyper-V,OU=Noeuds,OU=Cluster,OU=Tier-1,$DN"
                Credential = "$FQDN\Administrateur"
                Restart = $true
            }
            # Configurer d’abord l’adresse de serveur DNS avec celle du DC (10.1.40.10).
            Add-Computer @params -ErrorAction Stop
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