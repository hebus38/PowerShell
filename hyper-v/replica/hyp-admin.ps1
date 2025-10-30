# === VARIABLES ===
$dom = "kashyyyk.local"

# === 1. CRÉATION DE L’OU DE DÉLÉGATION ===
$ouClu = "OU=Cluster,OU=Tier-1,DC=kashyyyk,DC=local"

$ouParams = @{
    Name = "Delegation Administration Hyper-V"
    Path = $ouClu
    ProtectedFromAccidentalDeletion = $true
}
New-ADOrganizationalUnit @ouParams

# === 2. CRÉATION DU GROUPE DE DÉLÉGATION ===
$delegGroupName = "Delegation de l’administration Hyper-V"
$ouDeleg = "OU=Delegation Administration Hyper-V,OU=Cluster,OU=Tier-1,DC=kashyyyk,DC=local"

New-ADGroup -Name $delegGroupName `
            -GroupScope Global `
            -GroupCategory Security `
            -Path $ouDeleg `
            -Description "Groupe de délégation pour l’administration du cluster Hyper-V"

# === 3. CRÉATION DU COMPTE DÉDIÉ AU CLUSTER ===
$ouAdmin = "OU=Administrateurs Tier-1,OU=Tier-1,DC=kashyyyk,DC=local"
$ouAdminHV = "OU=Administrateur Hyper-V,$ouAdmin"
$svcAccountName = "svcAdminHV"

New-ADUser -Name $svcAccountName `
           -SamAccountName $svcAccountName `
           -AccountPassword (Read-Host -AsSecureString "Mot de passe pour $svcAccountName") `
           -Enabled $true `
           -Path $ouAdminHV `
           -Description "Compte de service pour l’administration du cluster Hyper-V"

# === 4. AJOUT DU COMPTE AU GROUPE DE DÉLÉGATION ===
$delegGroupName = "Delegation de l’administration Hyper-V"
$svcAccountName = "svcAdminHV"
Add-ADGroupMember -Identity $delegGroupName -Members $svcAccountName


# === 8. ACTIVATION DE L’AUDIT DES MODIFICATIONS DE GROUPES ===
auditpol /set /subcategory:"Security Group Management" /success:enable /failure:enable
