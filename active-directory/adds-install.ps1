<#
.SYNOPSIS
  Installation de Active Directory Domain Services
.LINK
  https://learn.microsoft.com/en-us/windows-server/identity/identity-and-access
  #>

$SRV = "SRV-DC-1"
$Psswrd = ConvertTo-SecureString "motDEpasse_1" -AsPlainText -Force
$Crdntl = New-Object System.Management.Automation.PSCredential ("SRV-HYP-1\Administrateur", $Psswrd)

try {
    Invoke-Command -VMName $SRV -Credential $Crdntl -ScriptBlock {
        try {
          Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

          $dsrm = ConvertTo-SecureString "MotDePasseDSRM!" -AsPlainText -Force
          #Test-ADDSForestInstallation ` <= Permet un TEST d’installation
          Install-ADDSForest `
          -DomainName "kashyyyk.local" `
          -DomainNetbiosName "KASHYYYK" `
          -SafeModeAdministratorPassword $dsrm `
          -InstallDNS:$true `
          -Force:$true
          Install-WindowsFeature -IncludeAllSubFeature -IncludeManagementTools Windows-Server-Backup
          #===
          $params = @{
            Identity = (
            "CN=NTDS Settings," +
            "CN=DC-1," +
            "CN=Servers," +
            "CN=Default-First-Site-Name," +
            "CN=Sites," +
            "CN=Configuration," +
            "DC=Kashyyyk," +
            "DC=Local"
            )
            Replace = @{
              options = 1
            }
          }
          Set-ADObject @params
          Get-ADDomainController -Filter * | Select-Object Name,IsGlobalCatalog
          #===
          Enable-ADOptionalFeature 'Recycle Bin Feature' -Scope ForestOrConfigurationSet `
          -Target "kashyyyk.local"

          #Set-ADDomainMode -Identity "kashyyyk.local" -DomainMode Windows2016Domain
          #Set-ADForestMode -Identity "kashyyyk.local" -ForestMode Windows2016Forest
        }
        catch {
            "`n"
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-Host $_.ScriptStackTrace -ForegroundColor Red

            if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                Write-Host $_.ErrorDetails.Message `
                -ForegroundColor DarkRed    
            }
            if ($_.Exception.InnerException) {
                Write-Host $_.Exception.InnerException `
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