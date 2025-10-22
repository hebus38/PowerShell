###
# VÉRIFICATIONS:
##
$property = (
  'Message', 
  'LogName', 
  'MachineName', 
  'LevelDisplayName'
)
Get-WinEvent -LogName "Directory Service" -MaxEvents 20 |
Select-Object -Property $property 

# DNS:
Get-DnsClientServerAddress | Format-List
Get-DnsServerZone | 
Select-Object ZoneName, ZoneType, IsDsIntegrated
Resolve-DnsName _ldap._tcp.dc._msdcs.kashyyyk.local -ErrorAction SilentlyContinue
Resolve-DnsName $env:COMPUTERNAME -ErrorAction SilentlyContinue
Get-DnsServerDiagnostics | Select-Object EnableLogFile, EnableLogging

# KERBEROS:
Get-Service -Name kdc | Format-List
$properties = @(
  'PSComputerName', 
  'InstanceID', 
  'LocalAddress', 
  'LocalPort', 
  'OwningProcess', 
  'RemoteAddress', 
  'RemotePort'
)
Get-NetTCPConnection -LocalPort 88 |
Select-Object -Property $properties 

Get-WinEvent -LogName "System" -MaxEvents 100 | Where-Object { $_.Message -like "*Kerberos*" }
Get-WinEvent -LogName "Security" -MaxEvents 100 | Where-Object { $_.Message -like "*Kerberos*" }
Get-WinEvent -LogName "Microsoft-Windows-Kerberos-Key-Distribution-Center/Operational"

