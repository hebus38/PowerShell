<#
.SYNOPSIS
Teste l’accès SMB à un partage Freebox et vérifie la présence du fichier unattend.xml.

.DESCRIPTION
Ce script monte un partage réseau SMB hébergé sur une Freebox, vérifie que le fichier unattend.xml est présent,
affiche son chemin complet, puis démonte le lecteur réseau proprement.

.LINK
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/net-use
#>

# === PARAMÈTRES ===
$sharePath     = "\\192.168.1.254\install"
$driveLetter   = "Z"
$targetFile    = "unattend.xml"
$credentials   = @{
    User     = "freebox"
    Password = "MotDePasse"  # Remplace par ton mot de passe réel
}

# === MONTAGE DU PARTAGE SMB ===
$netUseParams = @{
    LocalName = "$driveLetter`:"
    RemoteName= $sharePath
    UserName  = $credentials.User
    Password  = $credentials.Password
}

# Exécution de la commande net use
$cmd = "net use $($netUseParams.LocalName) $($netUseParams.RemoteName) /user:$($netUseParams.UserName) $($netUseParams.Password)"
Invoke-Expression $cmd

# === VÉRIFICATION DU FICHIER ===
$filePath = "$driveLetter`:\$targetFile"
if (Test-Path $filePath) {
    Write-Host "✅ Fichier '$targetFile' trouvé sur le partage SMB : $filePath"
} else {
    Write-Host "❌ Fichier '$targetFile' introuvable sur le partage SMB." -ForegroundColor Red
}

# === AFFICHAGE DU CONTENU DU DOSSIER ===
Write-Host "`n📂 Contenu du partage :"
Get-ChildItem "$driveLetter`:\" | Select Name, Length, LastWriteTime

# === DÉMONTAGE DU PARTAGE ===
Invoke-Expression "net use $driveLetter`: /delete"
Write-Host "`n🔌 Partage SMB démonté proprement."
