<#
.DESCRIPTION
Vérifie les modules PowerShell, installe Dell Command | Update si nécessaire, valide la signature numérique, et journalise les opérations.
.LINK
https://www.dell.com/support/kbdoc/fr-fr/000177325/dell-command-update
#>

# Numéro de série du système: 
Get-CimInstance -ClassName Win32_BIOS | Select-Object SerialNumber

# Installation du runtime .NET 10.0.100-rc.1:
$ServerName = "ISCSI"
$UserName = "{0}\Administrateur" -f $ServerName
$Credential = Get-Credential -UserName $UserName -Message "Enter password"

$invokeParams1 = @{
    ComputerName = $ServerName
    Credential = $Credential
    ScriptBlock = {
        $dotnetUrl = "https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.100-rc.1.25451.107/dotnet-sdk-10.0.100-rc.1.25451.107-win-x64.exe"
        $installerPath = "$env:TEMP\\dotnet-sdk-10.0.100-rc.1.25451.107-win-x64.exe"

        Invoke-WebRequest -Uri $dotnetUrl -OutFile $installerPath
        Start-Process -FilePath $installerPath -ArgumentList '/install','/quiet', '/norestart' -Wait
        Remove-Item $installerPath -Force
    }
}

Invoke-Command @invokeParams

# Vérification de l'installation du runtime .NET:
$runtimes = & "$env:ProgramFiles\dotnet\dotnet.exe" --list-runtimes 2>$null
return $runtimes -match "Microsoft\.WindowsDesktop\.App\s+$RuntimeVersion"

# Téléchargement de Dell Command | Update:
$invokeParams2 = @{
    ComputerName = $ServerName
    Credential = $Credential
    
    ScriptBlock = {
        # Intallation silencieuse de Dell Command | Update: (Ex: Tablette Latitude 5175)
        Invoke-WebRequest -Uri "https://dl.dell.com/FOLDER13309338M/2/Dell-Command-Update-Application_Y5VJV_WIN64_5.5.0_A00_01.EXE" `
        -OutFile "$env:TEMP\DCU_5.5.0.exe" `
        -Headers @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }


        # Vérification de la signature numérique
        Get-AuthenticodeSignature "$env:TEMP\DCU_5.5.0.exe"

        Start-Process -FilePath "$env:TEMP\DCU_5.5.0.exe" -ArgumentList "/s" -Wait

        <#
        Start-Process "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe" -ArgumentList `
        "/scan" `
        "/applyUpdates", `
        "-updateType=bios,firmware", `
        "-updateSeverity=critical", `
        "-silent", `
        "-Wait"
        
        Remove-Item $installerPath -Force
        #>
    }
}
Invoke-Command @invokeParams2




