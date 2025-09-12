# Identification des partitions pour chaque disque:
Get-Disk | ForEach-Object {
    $diskNum = $_.Number
    Write-Host "`n📦 Disque $diskNum: $($_.FriendlyName)"
    Get-Partition -DiskNumber $diskNum | Select-Object PartitionNumber, DriveLetter, Size
}

