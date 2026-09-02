Import-Module "./modules/Okta.psm1" -Force

$rbac = Get-Content "./config/rbac.json" |
    ConvertFrom-Json

Write-Host ""
Write-Host "OKTA RBAC GROUP SYNC"
Write-Host "--------------------"
Write-Host ""

$requiredGroups = @()

foreach ($role in $rbac.PSObject.Properties) {

    foreach ($group in $role.Value.groups) {
        $requiredGroups += $group
    }
}

$requiredGroups = $requiredGroups |
    Sort-Object -Unique

Write-Host "RBAC groups required:" $requiredGroups.Count
Write-Host ""

foreach ($group in $requiredGroups) {

    New-OktaGroup `
        -GroupName $group `
        -Description "RBAC entitlement managed by IAM Governance Platform"
}

Write-Host ""
Write-Host "Group synchronization complete."