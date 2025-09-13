# Identification des partitions pour chaque disque:
Get-Disk | ForEach-Object {
    $diskNum = $_.Number
    Write-Host "`n Disque {0}: $($_.FriendlyName)" -f $diskNum
    Get-Partition -DiskNumber $diskNum | 
    Select-Object PartitionNumber, DriveLetter, Size
}

<#
.DESCRIPTION
Vérifie la présence d'un module PowerShell, et l'installe si nécessaire.
.LINK
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/get-module
https://learn.microsoft.com/en-us/powershell/module/powershellget/install-module
#>
function Install-ModuleIfNeeded {
    param (
        [string] $ModuleName
    )
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "Import of $ModuleName module in progress..."
        Import-Module -Name $ModuleName -Force
    } else {
        Write-Host "Module $ModuleName already imported."
    }    
}
# Exécution distante avec authentification
$ServerName = "ISCSI"
$UserName = "{0}\Administrateur" -f $ServerName
$Credential = Get-Credential -UserName $UserName -Message "Enter password"
Invoke-Command -ComputerName $ServerName -Credential $Credential -ScriptBlock {
    Install-Module -Name "..." -Force -Scope CurrentUser
}

<#
.DESCRIPTION
Installation du runtime .NET 10.0.100-rc.1:

.LINK
https://learn.microsoft.com/en-us/dotnet/core/install/windows#install-with-powershell

.NOTES
Voir le script à télécharger.
#>

$ServerName = "ISCSI"
$UserName = "{0}\Administrateur" -f $ServerName
$Credential = Get-Credential -UserName $UserName -Message "Enter password"

$invokeParams = @{
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

<#
.DESCRIPTION
Divers
#>
Get-CimInstance -ClassName Win32_BIOS | Select-Object SerialNumber
