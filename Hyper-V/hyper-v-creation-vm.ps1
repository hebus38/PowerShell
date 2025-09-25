<#
.LINK
https://learn.microsoft.com/en-us/powershell/module/hyper-v/new-vm
#>

# Invoke-Command -FilePath ".\hyper-v-creation-vm.ps1" -ComputerName "HYPERV" -Credential "HYPERV\Administrateur"

param(
    [Parameter(Mandatory=$true)]
    [string]$VMName = "SRV-HYP-2"
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
    
    # Set boot order after all devices are added
    Add-VMDvdDrive -VMName $VMName -Path "E:\windows_server_2025.iso"
    Set-VMFirmware -VMName $VMName -BootOrder @(
        (Get-VMDvdDrive -VMName $VMName), 
        (Get-VMHardDiskDrive -VMName $VMName)
    )
}
catch {
    "`n"
    Write-Host $PSItem.Exception.Message -ForegroundColor Red
    #Write-Host $PSItem.Exception.InnerException -ForegroundColor Yellow
    #Write-Host $PSItem.Exception.Source -ForegroundColor Yellow
    #Write-Host $PSItem.Exception.TargetSite -ForegroundColor Yellow
    Write-Host $PSItem.ScriptStackTrace -ForegroundColor Red
    #Write-Host $PSItem.ErrorDetails.Message -ForegroundColor Yellow
    "`n"
}

    