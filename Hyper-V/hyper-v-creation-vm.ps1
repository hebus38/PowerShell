<#
.LINK
https://learn.microsoft.com/en-us/powershell/module/hyper-v/new-vm
#>
# Invoke-Command -FilePath ".\hyper-v-cluster-vm.ps1" -ComputerName "HYPERV" -Credential "HYPERV\Administrateur"

param(
    [Parameter(Mandatory=$true)]
    [string]$VMName = "SRV-HYP-1"
)
$VirtualMachine = @{
    Name = $VMName
    MemoryStartupBytes = 2048MB
    Generation = 2
    NewVHDPath = "C:\Virtual Machines\$VMName\$VMName.vhdx"
    NewVHDSizeBytes = 20GB
    BootDevice = "VHD"
    Path = "C:\Hyper-V"
    SwitchName = (Get-VMSwitch -Name "INT-vSwitch-Lab").Name
    ErrorAction = "Stop"
}

$roles = "Management", "Heartbeat", "Migration", "Storage", "VM"
try {
    New-VM @VirtualMachine
    foreach ($role in $roles) {
        $NetworkAdapters = @{
            VMName = $VMName    
            Name = "vNIC-{0}" -f $role
            SwitchName = "INT-vSwitch-Lab"
            ErrorAction = "Stop"
        }
        Add-VMNetworkAdapter @NetworkAdapters
    }    
}
catch {
    $PSItem.Exception.Message
    $PSItem.Exception.Source
    $PSItem.Exception.TargetSite
    $PSItem.ScriptStackTrace
    $PSItem.ErrorDetails.Message
}


    