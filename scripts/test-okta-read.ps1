Import-Module "./modules/Okta.psm1" -Force

Write-Host ""
Write-Host "OKTA GROUP TEST"
Write-Host "---------------"

$groups = Get-OktaGroups

Write-Host "Groups returned:" $groups.Count
Write-Host ""

$groups |
    Select-Object `
        id,
        @{Name="GroupName"; Expression={$_.profile.name}},
        type |
    Format-Table

Write-Host ""
Write-Host "OKTA USER LOOKUP TEST"
Write-Host "---------------------"

$user = Get-OktaUserByEmail `
    -Email "jane.doe@example.com"

if ($user) {
    Write-Host "User found:"
    Write-Host "ID:" $user.id
    Write-Host "Email:" $user.profile.email
    Write-Host "Status:" $user.status
}
else {
    Write-Host "User not found."
}