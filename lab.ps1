$psswrd = ConvertTo-SecureString "motDEpasse_1" -AsPlainText -Force
$crdntl = New-Object System.Management.Automation.PSCredential ("SRV-HYP-1\Administrateur", $psswrd)

$VMName = "DC-TEST-2"
Invoke-Command -VMName $VMName -Credential $Crdntl -ScriptBlock {Get-NetIPAddress | 
    Select-Object -Property ifIndex, IPv4Address, InterfaceAlias
}

Write-Progress -Activity "Configuration réseau de ${VMName}" `
    -Status "Test..."
try {
    Invoke-Command -VMName $VMName -Credential $Crdntl -ScriptBlock {
        
    }    
}
catch{
    "`n"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    "`n"    
}        