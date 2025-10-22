---------------------------------------
 --- POWERSHELL REMOTING AND LINUX ---
--------------------------------------- 
L’accès à distance via Powershell (pour Linux) se fait à l'aide de SSH.

Pour effectuer une connexion à distance en PowerShell entre machines Windows et Linux, vous devez installer SSH aux deux extrémités. 
PowerShell sous Windows utilise OpenSSH. 

.LIENS VERS LES DERNIÈRES VERSIONS D'OPENSSH:

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$URL = 'https://github.com/PowerShell/Win32-OpenSSH/releases/latest/'
$REQUEST = [System.Net.WebRequest]::Create($url)
$REQUEST.AllowAutoRedirect=$false
$RESPONSE=$REQUEST.GetResponse()
$URI = $([String]$RESPONSE.GetResponseHeader("Location")).Replace('tag','download') + '/OpenSSH-Win64.zip'
$URI = $([String]$RESPONSE.GetResponseHeader("Location")).Replace('tag','download') + '/OpenSSH-Win32.zip'


.TÉLÉCHARGEZ ET INSTALLEZ OPENSSH:

$OUTFILE = "C:\Users\ssit\Downloads\OpenSSH-Win64-v9.2.2.0.msi"

Invoke-WebRequest -Uri $URI -OutFile $OUTFILE


<# --- PAS vraiment NÉCESSAIRE --- #>

.MODIFIER LA VARIABLE D'ENVIRONNEMENT SYSTÈME:
setx PATH "$env:path;C:\Program Files\OpenSSH" -m
 #OU
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path",[System.EnvironmentVariableTarget]::Machine) + ';' + ${Env:ProgramFiles} + '\OpenSSH', [System.EnvironmentVariableTarget]::Machine)

.DÉMARRAGE AUTOMATIQUE DU SERVEUR SSH:
Get-Service -Name sshd | Set-Service sshd -StartupType Automatic
Start-Service sshd
#>


.AJOUT D'UNE RÈGLE DE PARE-FEU WINDOWS POUR AUTORISER LE TRAFIC SSH:
& "C:\Program Files (x86)\checkmk\service\check_mk_agent.exe" fw - configure

 #OU

New-NetFirewallRule -Name sshd -DisplayName 'Allow SSH' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22

.MODIFICATION DU SHELL PAR DÉFAUT POUR OPENSSH:
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "<PATH>" -PropertyType String -Force 


.DÉPLOIEMENT DE LA CLÉ PUBLIQUE:

 ---COMPTE ADMINISTRATEUR---
 
 #DEPUIS une machine LINUX: 
scp /etc/ssh/ssh_host_ed25519_key.pub  <USERNAME>@<HOSTNAME>:C:\ProgramData\ssh\administrators_authorized_keys

 #DEPUIS une machine WINDOWS:
$PUBLIC_KEY = Get-Content ~/.ssh/id_rsa.pub
ssh <USERNAME>@<HOSTNAME> "'$($PUBLIC_KEY)' | Out-File C:\ProgramData\ssh\administrators_authorized_keys -Encoding UTF8 -Append"

 #ACLs:
icacls "C:\ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"



--------------
 --- VOIR ---
--------------
https://learn.microsoft.com/fr-fr/windows-server/administration/windows-commands/icacls
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/get-acl?view=powershell-7.3

https://github.com/PowerShell/Win32-OpenSSH/wiki/Security-protection-of-various-files-in-Win32-OpenSSH#administrators_authorized_keys

https://learn.microsoft.com/fr-fr/windows-server/administration/openssh/openssh_keymanagement
https://learn.microsoft.com/en-us/powershell/scripting/learn/remoting/ssh-remoting-in-powershell-core?view=powershell-7.3

