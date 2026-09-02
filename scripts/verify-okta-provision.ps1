Import-Module "./modules/Okta.psm1" -Force

$email = "tsharp@example.net"

Write-Host ""
Write-Host "OKTA PROVISIONING VERIFICATION"
Write-Host "------------------------------"

$user = Get-OktaUserByEmail -Email $email

if (-not $user) {
    throw "User not found in Okta: $email"
}

Write-Host "User found:" $user.profile.email
Write-Host "Status:" $user.status
Write-Host "Okta ID:" $user.id

$groups = Get-OktaUserGroups -UserId $user.id

Write-Host ""
Write-Host "GROUP MEMBERSHIPS"
Write-Host "-----------------"

$groups |
    Select-Object `
        @{Name="GroupName"; Expression={$_.profile.name}},
        id,
        type |
    Format-Table