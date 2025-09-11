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
#>

$OutputEncoding = [System.Text.Encoding]::UTF8

# Vérification des droits administrateur et relance si besoin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Ce script doit être exécuté en tant qu'administrateur."# Relance automatique..."
    #$scriptPath = $MyInvocation.MyCommand.Path
    #$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    #Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}

# Vérification et création de la clé principale:
$registryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'
$productKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows'
$featureKey = 'CredentialsDelegation'

if (-not (Test-Path $registryKey)) {
	New-Item -Path $productKey -Name $featureKey  | Out-Null
	Write-Host ("La clé '{0}' a bien été créée." -f $featureKey)
} else {
	Write-Host ("La clé '{0}' est déjà présente." -f $featureKey)
}

# Vérification et création/modification des entrées:
$entry_1 = 'AllowFreshCredentialsWhenNTLMOnly'
$entry_2 = 'ConcatenateDefaults_AllowFreshNTLMOnly'

$entries = @(
	@{Name = $entry_1; Value = 1; Path = $registryKey},
	@{Name = $entry_2; Value = 1; Path = $registryKey}
)
foreach ($e in $entries) {
	$current = Get-ItemProperty -Path $e.Path -Name $e.Name -ErrorAction SilentlyContinue
	if ($null -eq $current) {
		New-ItemProperty -Path $e.Path -Name $e.Name -PropertyType DWord -Value $e.Value | Out-Null
		Write-Host ("L’entrée '$($e.Name)' a été créée avec la valeur $($e.Value).")
	} elseif ($current.$($e.Name) -ne $e.Value) {
		Set-ItemProperty -Path $e.Path -Name $e.Name -Value $e.Value
		Write-Host ("L’entrée '$($e.Name)' a été modifiée avec la valeur $($e.Value).")
	} else {    
		Write-Host ("L’entrée '$($e.Name)' existe déjà.")
	}
}

# Vérification et création de l’entrée spécifique:
$serverName = 'SRVHYPERV'

$subKey = "{0}\{1}" -f $registryKey, $entry_1

$entryValue = '1'
$entryData = "wsman/{0}" -f $serverName

$currentData = Get-ItemProperty -Path $subKey -Name $entryValue -ErrorAction SilentlyContinue
if ($null -eq $currentData) {
	New-ItemProperty -Path $subKey -Name $entryValue -PropertyType String -Value $entryData | Out-Null
	Write-Host ("La valeur {0} a été créée avec, pour donnée, {1}." -f $entryValue, $entryData)
} elseif ($currentData.$entryValue -ne $entryData) {
	Set-ItemProperty -Path $subKey -Name $entryValue -Value $entryData
	Write-Host ("La valeur {0} a été modifiée avec, pour donnée, {1}." -f $entryValue, $entryData)
} else {
	Write-Host ("L’entrée {0} est déjà configurée." -f $entry_1)
}

Read-Host "Appuyez sur Entrée pour quitter"
