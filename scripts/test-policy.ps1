Import-Module "./modules/Policy.psm1" -Force

$policies = Get-Content "./config/policies.json" |
    ConvertFrom-Json

$testGroups = @(
    "corp-basic",
    "vpn-access",
    "finance-read",
    "finance-admin"
)

$result = Test-AccessPolicy `
    -Groups $testGroups `
    -PolicyConfig $policies

Write-Host ""
Write-Host "APPROVED"

foreach ($group in $result.ApprovedGroups) {
    Write-Host "- $group"
}

Write-Host ""
Write-Host "DENIED"

foreach ($denied in $result.DeniedGroups) {
    Write-Host "- $($denied.Group)"
    Write-Host "  Reason: $($denied.Reason)"
}