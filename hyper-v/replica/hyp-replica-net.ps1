<#
.SYNOPSIS
    Configuration réseau pour la mise en oeuvre d’un cluster Hyper-V.

.DESCRIPTION
    Ce script illustre la configuration réseau nécessaires à la mise en oeuvre d’un cluster Hyper-V et 
    la fonctionnalité de réplication 'Hyper-V Replica', à partir de Windows Server Core 2022.

.NOTES
    Microsoft recommande de cloisonner les différents flux réseau nécessaires au cluster en VLANs distincts; 
    
    - Management: Assure la connectivité entre le serveur exécutant Hyper-V et les fonctionnalités 
    d'infrastructure de base. Permet de gérer Hyper-V et les machines virtuelles.

    - Cluster: Utilisé pour la communication entre noeuds du cluster, comme le 'heartbeat' du cluster et la 
    redirection des volumes partagés du cluster (CSV).

    - Live Migration: Utilisé pour la migration à chaud des machines virtuelles.

    - Stockage: Utilisé pour les flux SMB ou iSCSI.

    - Réplication : Utilisé pour la réplication des machines virtuelles via la fonctionnalité de 
    réplication Hyper-V.

    - Accès réseau: Utilisé pour la connectivité des machines virtuelles. Nécessite généralement une 
    connectivité réseau externe pour répondre aux requêtes des clients.

    Topologie réseau:
    -----------------
    Stockage:   10.1.10.0/24    255.255.255.0   vlan10
    Cluster:    10.1.20.0/24    255.255.255.0	vlan20
    Migration:	10.1.30.0/24	255.255.255.0	vlan30
    Réseau: 	10.1.40.0/24	255.255.255.0	vlan40
    Management:	10.1.50.0/24	255.255.255.0	vlan50

.LINK
    https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/dn550728(v=ws.11)
#>

###
# VÉRIFICATION INITIALE:
##
Get-VMSwitch

# Vérification depuis l’hôte Hyper-V principal, de certaines informations de COUCHE 2 et 3 concernant les 
# cartes réseau virtuelles (vNIC) d’un noeud du cluster:
$SRV = "SRV-HYP-1"
$properties = @(
    'Name'
    'SwitchName'
    'MACAddress'
    'DynamicMacAddressEnabled'
    'IPAddresses'
)
Get-VMNetworkAdapter -VMName $SRV |
Select-Object -Property $properties |
Format-List

# Vérification des paramètres VLAN d’un noeud du cluster:
Get-VMNetworkAdapterVlan -VMName $SRV | 
Format-List
#===
$Psswrd = ConvertTo-SecureString "motDEpasse_1" -AsPlainText -Force
$Crdntl = New-Object System.Management.Automation.PSCredential ("$SRV\Administrateur", $Psswrd)

# Vérification depuis la machine virtuelle de certaines informations de COUCHE 2: 
Invoke-Command -VMName $SRV -Credential $Crdntl -ScriptBlock {
    $properties = @(
        'MacAddress'
        'MediaConnectionState'
        'InterfaceAlias' 
        'ifIndex' 
        'Name' 
        'PermanentAddress'
        'VlanID'
    )
    Get-NetAdapter | 
    Select-Object -Property $properties |
    Format-List
}

# Vérification depuis la machine virtuelle de certaines informations de COUCHE 3:
Invoke-Command -VMName $SRV -Credential $Crdntl -ScriptBlock {
    $properties = @(
        'InterfaceIndex'
        'InterfaceAlias'
        'AddressFamily'
        'Dhcp'
        'ConnectionState'
    )
    Get-NetIPInterface -AddressFamily IPv4 | 
    Select-Object -Property $properties |
    Format-List
}
#===
Invoke-Command -VMName $SRV -Credential $Crdntl -ScriptBlock {
    $properties = @(
        'IPv4Address'
        #'IPv6Address'
        'PrefixLength'
        'InterfaceAlias'
        'InterfaceIndex'
    )
    Get-NetIPAddress -AddressFamily IPv4 | Select-Object -Property $properties |
    Format-Table -AutoSize
}

##
# FONCTIONS:
##
<#
.SYNOPSIS
    Récupère l’état d’une VM.
#>
function Get-VMState {
    param (
        [Parameter(Mandatory=$true)]
        [string]$VMName
    )
    Write-Progress -Activity "Récupération de l’état de ${VMName}:" -Status "En cours..."
    try {
        $VMState = (Get-VM -Name $VMName -ErrorAction Stop).State
        start-sleep -Seconds 2
    } catch {
        "`n"
        Write-Host $_.Exception.Message -ForegroundColor Red
        "`n"
    }
    return $VMState    
}

<#
.SYNOPSIS
    Convertit l’adresse MAC délivrée par Hyper-V au format EUI-48 avec séparateur (-), selon la convention 
    Windows.
.DESCRIPTION
    Capture dans le groupe $1 chaque paire de caractères '(.{2})' et remplace par '$1-', 
    à condition que ce qui suit (?=...) corresponde à au moins deux caractères quelconques .{2,}
    puis met en majuscule avec ToUpper().
#>  
function Convert-MacToDashFormat {
    param([string]$MAC)
    return ($MAC -replace '(.{2})(?=.{2,})', '$1-').ToUpper()
}

##
# CONFIGURATION DES NOEUDS DU CLUSTER:
##
$SRV = "SRV-HYP-2"
$Psswrd = ConvertTo-SecureString "motDEpasse_1" -AsPlainText -Force
$Crdntl = New-Object System.Management.Automation.PSCredential ("$SRV\Administrateur", $Psswrd)

# Configuration d’une MAC statique sur chaque vNIC de 'SRV-HYP-2': 
# La machine doit être arrétée...
if (( Get-VMState -VMName $SRV -ErrorAction SilentlyContinue) -eq "Running" ){
    Write-Progress -Activity "Modification de l’état de ${SRV}:" -Status "En cours..."
    try {
        Stop-VM -Name $SRV -Force -ErrorAction Stop
        start-sleep -Seconds 5
    }
    catch {
        "`n"
        Write-Host $_.Exception.Message -ForegroundColor Red
        "`n"
    }
}

Get-VMNetworkAdapter -VMName $SRV | ForEach-Object {
    $vNICName = $_.Name
    $vNICMac = $_.MacAddress
    $staticMacAddress = Convert-MacToDashFormat -MAC $vNICMac
    Write-Progress -Activity "Configuration d’une MAC statique sur ${vNICName}:" -Status "En cours..." 
    try {
        Set-VMNetworkAdapter -VMName $SRV `
            -Name $vNICName `
            -StaticMacAddress $staticMacAddress `
            -ErrorAction Stop
        start-sleep -Seconds 2
    }
    catch {
        "`n"
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        "`n"
    }
}

Write-Progress -Activity "Démarrage de ${SRV}:" -Status "En cours..."
Start-VM -Name $SRV
Start-Sleep -Seconds 10

# Modification de chaque vNIC: changement de nom, MAC statique, IP statique, VLANs;
$PermanentAddress = '00155D27D004'
$NewName = 'NICNode1Heartbeat'
$IPAddress = '10.1.20.11'
#$DefaultGateway = '10.1.50.254'
#=
$VMNetworkAdapterName = 'vNIC-Hearbeat'
$VlanID = 20
$Switch = 'vSwitch-CLU'
#====
try {
    Invoke-Command -VMName $SRV -Credential $Crdntl -ScriptBlock {
        param(
            [Parameter(Mandatory=$true)]
            [String]$permanentAddress,
            [string]$newName,
            [System.Net.IPAddress]$ipAddress,
            [System.Net.IPAddress]$defaultGateway
        )        
        try {
            $name = Get-NetAdapter | Where-Object { $_.PermanentAddress -eq $permanentAddress } | 
            Select-Object -ExpandProperty Name -ErrorAction Stop
            Start-Sleep -Seconds 4
            Write-Host "`nApplication des paramètres: Le nom actuel de ${permanentAddress} est ${name}...n" `
            -ForegroundColor Yellow
            ###
            Write-Progress -Activity "$name est renommée en ${newName}:"
            Rename-NetAdapter -Name $name -NewName $newName -ErrorAction Stop
            Start-Sleep -Seconds 2
            ###
            Write-Progress "Une IP statique est assignée à ${newName}:"
            $params1 = @{
                InterfaceAlias = $newName
                IPAddress = $ipAddress 
                PrefixLength = 24
                DefaultGateway = $defaultGateway
                ErrorAction = 'Stop'
            }
            $params2 = @{
                InterfaceAlias = $newName
                ServerAddresses = '192.168.1.254'
            }
            New-NetIPAddress @params1 
            Set-DnsClientServerAddress @params2
            Start-Sleep -Seconds 1
        }
        catch {
            "`n"
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-Host $_.ScriptStackTrace -ForegroundColor Red

            if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                Write-Host $_.ErrorDetails.Message `
                -ForegroundColor DarkRed    
            }
            "`n"
        }
    } -ArgumentList $PermanentAddress, $NewName, $IPAddress, $DefaultGateway -ErrorAction Stop
}
catch {
    #"`n"
    Write-Host "`n$_.Exception.Message`n" -ForegroundColor Red
    #"`n"
    if ($_.Exception.InnerException) {
        Write-Host "`n$_.Exception.InnerException`n" -ForegroundColor DarkRed
    }
    #"`n"
}

Set-VMNetworkAdapterVlan -VMName $SRV -VMNetworkAdapterName $VMNetworkAdapterName -Access -VlanId $VlanID
Connect-VMNetworkAdapter -VMName $SRV -Name $VMNetworkAdapterName -SwitchName $Switch
