
<#
.LINK
https://learn.microsoft.com/en-us/dotnet/api/system.io.file?view=net-8.0
.NOTES
🧠 $file.Read($buffer, 0, 4MB)
Méthode : FileStream.Read
Signature : int Read(byte[] array, int offset, int count)
Rôle : lit jusqu’à count octets dans le flux, à partir de la position actuelle, et les place dans array à partir de offset
Retour : nombre d’octets réellement lus (peut être < count en fin de fichier)

🔹 Ici, tu lis par blocs de 4 Mo, ce qui est optimal pour les gros fichiers 
🔸 Tu pourrais aussi utiliser ReadAsync si tu veux paralléliser ou éviter le blocage

🧠 $out.Write($buffer, 0, $read)
Méthode : FileStream.Write
Signature : void Write(byte[] array, int offset, int count)
Rôle : écrit count octets depuis array dans le flux, à partir de offset

🔹 Tu écris exactement ce que tu viens de lire, sans surcharge ni transformation
============
using ($inStream = [System.IO.File]::OpenRead($source))
using ($outStream = [System.IO.File]::Create($destination)) {
    # boucle de copie ici
}
===
$hashSource = Get-FileHash $source -Algorithm SHA256
$hashDest = Get-FileHash $destination -Algorithm SHA256
if ($hashSource.Hash -ne $hashDest.Hash) {
    Write-Warning "La copie est corrompue !"
}
#>
$source = "\\PORTABLE-WIN11\Partage\OPNsense-25.7-dvd-amd64.iso"
$target = "E:\OPNsense-25.7-dvd-amd64.iso"
$lenght = (Get-Item $source).Length
$size = 4MB
$bytes = 0

$file = [System.IO.File]::OpenRead($source)
$copy = [System.IO.File]::Create($target)
$buffer = New-Object byte[] $size

while (($read = $file.Read($buffer, 0, $size)) -gt 0) {
    $copy.Write($buffer, 0, $read)
    $bytes += $read
    $percent = [math]::Round(($bytes/$lenght) * 100, 2)
    
    Write-Progress -Activity "`nCopie en cours" `
	-Status "${percent}% terminé" `
	-PercentComplete $percent
}

$file.Close()
$copy.Close()





