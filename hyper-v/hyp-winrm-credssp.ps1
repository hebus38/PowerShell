<#
  .SYNOPSIS
  	Configure la délégation d'identifiants pour Hyper-V via la stratégie locale.

  .DESCRIPTION
  	Ce script vérifie et crée/modifie les clés et valeurs nécessaires dans le registre pour permettre la 
  	délégation d'identifiants sur Hyper-V (WSMAN/NTLM). 
   
  	Il doit être exécuté en tant qu'administrateur local.

  .LINK
  	https://learn.microsoft.com/en-us/powershell/scripting/samples/working-with-registry-entries?view=powershell-7.5
  	https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2003/cc781906(v=ws.10)

  .NOTES
  Auteur : Olivier BERTRAND
  Date   : 09/2025
  Version: 2.0

  .TODO: Ajouter un hôte de confiance pour WinRM sans écraser les existants:
	$current = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
	$newHosts = "SRVCORE03,192.168.1.11"

	if ($current -and $current -ne "*") {
    	$combined = "$current,$newHosts"
	} else {
    	$combined = $newHosts
	}

	Set-Item WSMan:\localhost\Client\TrustedHosts -Value $combined

  .TODO: Ajouter fonctions
#>

# Vérification et création de la clé principale:
$registryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'
$productKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows'
$featureKey = 'CredentialsDelegation'

if (-not (Test-Path $registryKey)) {
	$params1 = @{
		Path = $productKey
		Name = $featureKey
	}
	New-Item  @params1 
} else {
	Write-Host ("La clé '{0}' existe déjà." -f $featureKey)
}

# Vérification et création/modification des entrées:
$entry_1 = 'AllowFreshCredentialsWhenNTLMOnly'
$entry_2 = 'ConcatenateDefaults_AllowFreshNTLMOnly'

$entries = @(
	@{Name = $entry_1; Value = 1; Path = $registryKey},
	@{Name = $entry_2; Value = 1; Path = $registryKey}
)
foreach ($e in $entries) {
	$params2 = @{
		Path = $e.Path
		Name = $e.Name		
	}
	$current = Get-ItemProperty @params2 -ErrorAction SilentlyContinue
	if ($null -eq $current) {
		$params3 = @{
			Path = $e.Path 
			Name = $e.Name 
			PropertyType = 'DWord' 
			Value = $e.Value
		}
		New-ItemProperty @params3
	} elseif ($current.$($e.Name) -ne $e.Value) {
		$params3 = @{
			Path = $e.Path 
			Name = $e.Name 
			PropertyType = 'DWord' 
			Value = $e.Value
		}
		Set-ItemProperty @params3
	} else {    
		Write-Host ("L’entrée '$($e.Name)' existe déjà.")
	}
}

# Vérification et création de l’entrée spécifique:
$serverName = 'SRV-HYP-1.kashyyyk.local'
#$subKey = "{0}\{1}" -f $registryKey, $entry_1
$entryValue = '1'
$entryData = "wsman/{0}" -f $serverName

$currentData = Get-ItemProperty -Path $registryKey -Name $entryValue -ErrorAction SilentlyContinue
if ($null -eq $currentData) {
    $params = @{
        Path = $registryKey
        Name = $entryValue
        PropertyType = 'String'
        Value = $entryData
    }
	New-ItemProperty @params 
} elseif (-not ($currentData.$entryValue -contains $entryData)) { #NE MARCHE PAS
    $params = @{
        Path = $registryKey
        Name = $entryValue
        PropertyType = 'String'
        Value = $entryData
    }    
	Set-ItemProperty @params
} else {
	Write-Host ("L’entrée {0} est déjà configurée." -f $entry)
}

Read-Host "Appuyez sur Entrée pour quitter"