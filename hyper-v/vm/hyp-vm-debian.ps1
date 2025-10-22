<#
.SYNOPSIS
    Création d’une machine virtuelle Debian

.DESCRIPTION
    Création d’une machine virtuelle Debian avec 3 cartes réseaux virtuelles (vNIC) dont une dédiée pour
    la mise en place d’un cluster HA avec Corosync/Pacemaker. 
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
    Add-VMNetworkAdapter -VMName $VMName -Name "vNIC-Xtrnl" -SwitchName "vSwitch-WAN" -ErrorAction Stop
    Add-VMNetworkAdapter -VMName $VMName -Name "vNIC-Ntwrk" -SwitchName "vSwitch-LAN" -ErrorAction Stop
    Add-VMNetworkAdapter -VMName $VMName -Name "vNIC-Clstr" -SwitchName "vSwitch-CLU" -ErrorAction Stop

    Set-VMNetworkAdapterVlan -VMName $VMName -VMNetworkAdapterName "vNIC-Ntwrk" -Access -VlanId 40
    Set-VMNetworkAdapterVlan -VMName $VMName -VMNetworkAdapterName "vNIC-Clstr" -Access -VlanId 21

    Add-VMDvdDrive -VMName $VMName `
        -Path "C:\ISO\debian-13.1.0-amd64-netinst.iso"
    
    Set-VMFirmware -VMName $VMName -EnableSecureBoot On `
        -SecureBootTemplate "MicrosoftUEFICertificateAuthority"
    
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
    