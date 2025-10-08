<#
.LINK
https://learn.microsoft.com/en-us/powershell/module/hyper-v/new-vm

.NOTES
Invoke-Command -FilePath ".\hyper-v-creation-vm.ps1" -ComputerName "HYPERV" -Credential "HYPERV\Administrateur"
#>

###
# Vérification de la mémoire avant création des VMs:
##
$computerName = $env:COMPUTERNAME
$os = Get-CimInstance win32_operatingsystem -Property TotalVisibleMemorySize,FreePhysicalMemory -Computername $computerName
$inUseMemory = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1kB
Write-Host "Used memory: $([math]::Round($inUseMemory/1GB,2))GB"

###
# Création des 'vSwitch' pour le lab:
##
New-VMSwitch -Name "EXT-vSwitch-Lab" -SwitchType External -NetAdapterName "Ethernet" -AllowManagementOS $true
New-VMSwitch -Name "INT-vSwitch-Lab" -SwitchType Internal
New-VMSwitch -Name "PRV-vSwitch-Lab" -SwitchType Private

<#
.SYNOPSIS
    Création des VMs Hyper-V (SRV-HYP-1 et SRV-HYP-2):
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$VMName # SRV-HYP-1
)
$VirtualMachine = @{
    Name = $VMName
    MemoryStartupBytes = 2048MB
    Generation = 2
    NewVHDPath = "C:\Virtual Machines\$VMName\$VMName.vhdx"
    NewVHDSizeBytes = 20GB
    BootDevice = "VHD"
    Path = "C:\Hyper-V"
    #SwitchName = (Get-VMSwitch -Name "EXT-vSwitch").Name
    ErrorAction = "Stop"
}

$INTRoles = "Heartbeat", "Migration"
$EXTRoles = "Management", "Storage", "VM"
try {
    New-VM @VirtualMachine

    foreach ($role in $INTRoles) {
        $NetworkAdapters = @{
            VMName = $VMName    
            Name = "vNIC-{0}" -f $role
            SwitchName = "INT-vSwitch"
            ErrorAction = "Stop"
        }
        Add-VMNetworkAdapter @NetworkAdapters
    }
    foreach ($role in $EXTRoles) {
        $NetworkAdapters = @{
            VMName = $VMName    
            Name = "vNIC-{0}" -f $role
            SwitchName = "EXT-vSwitch"
            ErrorAction = "Stop"
        }
        Add-VMNetworkAdapter @NetworkAdapters
    }
    
    Add-VMDvdDrive -VMName $VMName -Path "E:\windows_server_2025.iso"
    Set-VMFirmware -VMName $VMName -BootOrder @(
        (Get-VMDvdDrive -VMName $VMName), 
        (Get-VMHardDiskDrive -VMName $VMName)
    )
}
catch {
    "`n"
    Write-Host $PSItem.Exception.Message -ForegroundColor Red
    Write-Host $PSItem.ScriptStackTrace -ForegroundColor Red
    "`n"
}

<#
.SYNOPSIS
    Création d’un contrôleur de domaine
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$VMName
)
$VirtualMachine = @{
    Name = $VMName
    MemoryStartupBytes = 2048MB
    Generation = 2
    NewVHDPath = "C:\Virtual Machines\$VMName\$VMName.vhdx"
    NewVHDSizeBytes = 20GB
    BootDevice = "VHD"
    Path = "C:\Hyper-V"
    ErrorAction = "Stop"
}

try {
    New-VM @VirtualMachine
    $NetworkAdapters = @{
        VMName = $VMName    
        Name = "vNIC-Management" 
        SwitchName = "vSwitch-WAN"
        ErrorAction = "Stop"
    }
    Add-VMNetworkAdapter @NetworkAdapters

    
    Add-VMDvdDrive -VMName $VMName -Path "E:\windows_server_2025.iso"
    Set-VMFirmware -VMName $VMName -BootOrder @(
        (Get-VMDvdDrive -VMName $VMName), 
        (Get-VMHardDiskDrive -VMName $VMName)
    )
}
catch {
    "`n"
    Write-Host $PSItem.Exception.Message -ForegroundColor Red
    Write-Host $PSItem.ScriptStackTrace -ForegroundColor Red
    "`n"
}

<#
.SYNOPSIS
    Création d’une machine virtuelle Debian
.LINK
    https://opnsense.org/    
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$VMName
)

$VirtualMachine = @{
    Name = $VMName
    MemoryStartupBytes = 2048MB  
    Generation = 2
    NewVHDPath = "C:\Virtual Machines\$VMName\$VMName.vhdx"
    NewVHDSizeBytes = 20GB       
    BootDevice = "VHD"
    Path = "C:\Hyper-V"
    ErrorAction = "Stop"
}

try {
    
    New-VM @VirtualMachine
    Add-VMNetworkAdapter -VMName $VMName -Name "vNIC-WAN" -SwitchName "vSwitch-WAN" -ErrorAction Stop
    Add-VMNetworkAdapter -VMName $VMName -Name "vNIC-LAN" -SwitchName "vSwitch-LAN" -ErrorAction Stop
    Add-VMDvdDrive -VMName $VMName -Path "C:\ISO\debian-13.1.0-amd64-netinst.iso"
    Set-VMFirmware -VMName $VMName -EnableSecureBoot Off
    Set-VMFirmware -VMName $VMName -BootOrder @(
        (Get-VMDvdDrive -VMName $VMName),
        (Get-VMHardDiskDrive -VMName $VMName)
    )

    Write-Host "`nVM '$VMName' créée avec succès.`n" -ForegroundColor Cyan
}
catch {
    "`n"
    Write-Host $PSItem.Exception.Message -ForegroundColor Red
    Write-Host $PSItem.ScriptStackTrace -ForegroundColor Red
    "`n"
}
    