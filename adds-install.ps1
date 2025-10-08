<#
.SYNOPSIS
  Installation de Active Directory Domain Services
.LINK
  https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/deploy/install-active-directory-domain-services--level-100-
#>

$vmname = "SRV-DC-1"
$psswrd = ConvertTo-SecureString "motDEpasse_1" -AsPlainText -Force
$crdntl = New-Object System.Management.Automation.PSCredential ("SRV-HYP-1\Administrateur", $psswrd)

Invoke-Command -VMName $vmname  -Credential $crdntl {...}

Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

$dsrm = ConvertTo-SecureString "MotDePasseDSRM!" -AsPlainText -Force

#Test-ADDSForestInstallation `
Install-ADDSForest `
  -DomainName "lothlorien.local" `
  -DomainNetbiosName "LOTHLORIEN" `
  -SafeModeAdministratorPassword $dsrm `
  -InstallDNS:$true `
  -Force:$true

Install-WindowsFeature -IncludeAllSubFeature -IncludeManagementTools Windows-Server-Backup
#===
$params = @{
    Identity = 
        "CN=NTDS Settings," +
        "CN=SRV-DC-1," +
        "CN=Servers," +
        "CN=Default-First-Site-Name," +
        "CN=Sites," +
        "CN=Configuration," +
        "DC=Lothlorien," +
        "DC=Local"
        
    Replace = @{
        options = '1'
    }
}

Set-ADObject @params
Get-ADDomainController -Filter * | Select-Object Name,IsGlobalCatalog
#===
Enable-ADOptionalFeature 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target "lothlorien.local"

Set-ADDomainMode -Identity "lothlorien.local" -DomainMode Windows2016Domain
Set-ADForestMode -Identity "lothlorien.local" -ForestMode Windows2016Forest

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

===
5. 🌐 Déploiement du portail de téléservices
Serveur web en DMZ (IIS, Apache, Nginx)

Authentification AD via LDAP ou Kerberos

Ciblage DNS vers le RODC uniquement

Test de connexion avec agent.etatcivil
===
Présence du RODC: Get-ADDomainController -Filter {IsReadOnly -eq $true}
Réplication: repadmin /showrepl
























