<#
.SYNOPSIS
    Création d’une arborescence Active Directory minimale pour un SI sécurisé selon les recommandations 
    de l’ANSSI.

.DESCRIPTION
    Ce script crée les OU, groupes et comptes nécessaires pour isoler les rôles, machines et 
    administrateurs Hyper-V.

.PARAMETER domain
    Nom LDAP du domaine (ex: DC=kashyyyk,DC=local)
.PARAMETER hvAdmin
    Nom du compte d’administration Hyper-V (ex: HVAdmin-Olivier)
.PARAMETER hvAdminPassword
    Mot de passe du compte Hyper-V (en clair ou sécurisé)
#>
$SRV = "DC-1"
$Domain = "kashyyyk.local"
$Psswrd = ConvertTo-SecureString "motDEpasse_1" -AsPlainText -Force
$Crdntl = New-Object System.Management.Automation.PSCredential ("$Domain\Administrateur", $Psswrd)

try {
    Invoke-Command -VMName $SRV -Credential $Crdntl -ScriptBlock {
        ##
        # FUNCTION:
        #
        function New-TiersOrganizationalUnits {
            [CmdletBinding(SupportsShouldProcess=$true)]
            param (
                [Parameter(Mandatory, ValueFromPipeline)]
                [string[]]$ouList,

                [Parameter(Mandatory=$true)]
                [string]$domain
            )
            process {
                Write-Progress -Activity "Création des unités d’organisation:"
                
                foreach($ou in $ouList){
                    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=$ou)")) {
                        $ou -match '^OU=(?<ouName>[^,]+),(?<ouParent>.*)$' | Out-Null
                        $ouName = $Matches.ouName
                        $ouParent = $Matches.ouParent 

                        $params = @{
                            Name = $ouName 
                            Path = $ouParent 
                        }
                        New-ADOrganizationalUnit @params -ErrorAction Stop #-WhatIf
                        #Write-Host "${ouParent}: $ouName`n"
                        Start-Sleep -Seconds 3
                    } 
                }
            }
        }       
        #
        # FUNCTION
        ##
        try {
            $domain = "DC=kashyyyk,DC=local"
            
            $ouList0 = @(
                "OU=Tier-0,$domain"
                "OU=Administrateurs Tier-0,OU=Tier-0,$domain"
                "OU=Administrateur DC,OU=Administrateurs Tier-0,OU=Tier-0,$domain"
            )
            $ouList1 = @(
                "OU=Tier-1,$domain"
                "OU=Cluster,OU=Tier-1,$domain"
                "OU=Noeuds,OU=Cluster,OU=Tier-1,$domain"
                "OU=Hyper-V,OU=Noeuds,OU=Cluster,OU=Tier-1,$domain"
                "OU=Administrateurs Tier-1,OU=Tier-1,$domain"
                "OU=Administrateur Hyper-V,OU=Administrateurs Tier-1,OU=Tier-1,$domain"
                #"OU=Comptes de Services,OU=Tier-1,$domain"
            )
            $ouList2 = @(
                "OU=Tier-2,$domain"
                "OU=Clients,OU=Tier-2,$domain"
                "OU=Administrateurs Tier-2,OU=Tier-2,$domain"
            )
            $listing = @(
                    $ouList0
                    $ouList1
                    $ouList2
                )

            #$grpName = "Administrateurs Hyper-V"
            #$grpPath = "OU=Administrateur Hyper-V,OU=Comptes Administrateur,$domain"
            #$userPath  = $GroupPath
            
            ###
            # MAIN
            ##
            foreach($oulist in $listing){
                New-TiersOrganizationalUnits -ouList $oulist -domain $domain
            }
            ###
            # MAIN
            ##
        }        
        catch {
            "`n"
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-Host $_.ScriptStackTrace -ForegroundColor Red

            if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                Write-Host $_.ErrorDetails.Message `
                -ForegroundColor DarkRed    
            }
            if ($_.Exception.InnerException) {
                Write-Host $_.Exception.InnerException `
                -ForegroundColor DarkRed
            }
            "`n"
        }
    } -ErrorAction Stop
}
catch {
    "`n"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    "`n"
}