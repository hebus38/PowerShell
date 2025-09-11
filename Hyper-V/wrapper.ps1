# Vérifie si le script est en mode administrateur
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $IsAdmin) {
    Write-Warning "Relance du script en mode administrateur..."
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy Bypass", "-File `"$scriptPath`"" -Verb RunAs
    exit
}

# Encodage UTF-8 pour les accents
$OutputEncoding = [System.Text.Encoding]::UTF8

# Centre et redimensionne la fenêtre PowerShell
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win {
    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
}
"@

$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$width = 900
$height = 400
$x = [Math]::Max(0, ($screen.Width - $width) / 2)
$y = [Math]::Max(0, ($screen.Height - $height) / 2)

[Win]::MoveWindow([Win]::GetForegroundWindow(), $x, $y, $width, $height, $true)

# Test d'affichage
Write-Host "`nFenêtre centrée. Encodage UTF-8 actif. Les accents s'affichent : é, è, à, ç"

# Pause finale fiable
Write-Host "`nAppuyez sur une touche pour quitter..."

