#===
#= RODC
#===

New-ADGroup -Name "RODC_Cached_Users" -GroupScope Global -Path "OU=Agents,DC=<...>,DC=local"
New-ADGroup -Name "RODC_Admins" -GroupScope Global -Path "OU=Admin,DC=<...>,DC=local"

Add-ADGroupMember -Identity "RODC_Cached_Users" -Members agent.etatcivil, agent.urbanisme

Install-WindowsFeature AD-Domain-Services

Install-ADDSDomainController `
  -DomainName "lothlorien.local" `
  -ReadOnlyReplica `
  -SiteName "DMZ-Test" `
  -Credential (Get-Credential) `
  -DelegatedAdministratorAccountName "RODC_Admins" `
  -InstallDns:$true `
  -NoGlobalCatalog:$false

===
Set-ADDomainControllerPasswordReplicationPolicy `
  -Identity "RODC01" `
  -AllowedList "RODC_Cached_Users"
=
Get-ADDomainControllerPasswordReplicationPolicy `
  -Identity "RODC01" `
  -AllowedList