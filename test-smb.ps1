<#
.SYNOPSIS
Teste l’accès 'SMB' à un partage réseau et vérifie la présence d’un fichier spécifié.

.DESCRIPTION
Ce script monte un partage SMB hébergé sur un réseau, vérifie la présence du fichier spécifié, 
affiche son chemin complet, puis démonte le lecteur réseau proprement.

.LINK
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/new-psdrive?view=powershell-7.5
#>

$partage = "\\192.168.1.254\Disque dur\Partage"
$lecteur = "Z"
$fournisseur = "FileSystem"
$cible = "test.txt"

$params = @{
    Name = "$lecteur"
    PSProvider = $fournisseur
    Root = $partage
    Persist = $false
}
if (-not (Get-PSDrive -Name $lecteur -ErrorAction SilentlyContinue)) {
    New-PSDrive @params
}

$chemin = "{0}:\{1}" -f $lecteur, $cible    

if (Test-Path $chemin) {
    Write-Host "`nLe fichier $cible est bien présent sur le partage: $partage"
    Get-ChildItem ("{0}:\" -f $lecteur) 
} else {
    Write-Warning "Le fichier $cible est introuvable sur le partage: $partage"
}

Remove-PSDrive -Name $lecteur -Confirm:$true