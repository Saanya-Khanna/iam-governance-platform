param (
    [Parameter(Mandatory)]
    [string]$Email
)

Import-Module "./modules/Okta.psm1" -Force
Import-Module "./modules/Logging.psm1" -Force

$reportPath = "./reports/access-certification.csv"

if (-not (Test-Path $reportPath)) {
    throw "Access certification report not found: $reportPath"
}

$review = Import-Csv $reportPath |
    Where-Object { $_.Email -eq $Email } |
    Select-Object -First 1

if (-not $review) {
    throw "No access review record found for: $Email"
}

Write-Host ""
Write-Host "MISSING ACCESS REMEDIATION"
Write-Host "=========================="
Write-Host "Email:" $review.Email
Write-Host "Finding:" $review.Status
Write-Host ""

if ($review.Status -ne "MISSING_ACCESS") {
    throw "This script only remediates MISSING_ACCESS findings."
}

$missingGroups = @(
    $review.MissingAccess -split ";" |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        }
)

if ($missingGroups.Count -eq 0) {
    throw "Finding is MISSING_ACCESS but no missing groups were listed."
}

# Defense-in-depth:
# Never grant something unless it also appears in ExpectedGroups.

$expectedGroups = @(
    $review.ExpectedGroups -split ";" |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        }
)

foreach ($group in $missingGroups) {

    if ($group -notin $expectedGroups) {
        throw "Refusing to grant '$group' because it is not an expected RBAC entitlement."
    }
}

$oktaUser = Get-OktaUserByEmail -Email $review.Email

if (-not $oktaUser) {
    throw "Okta user not found: $($review.Email)"
}

Write-Host "RBAC-approved groups to restore:"

foreach ($group in $missingGroups) {
    Write-Host "-" $group
}

foreach ($group in $missingGroups) {

    try {

        Add-OktaUserToGroup `
            -UserId $oktaUser.id `
            -GroupName $group

        Write-AuditLog `
            -Email $review.Email `
            -Action "MISSING_ACCESS_REMEDIATION" `
            -Target $group `
            -Result "SUCCESS" `
            -Reason "Restored missing RBAC-approved entitlement identified during certification."
    }
    catch {

        Write-AuditLog `
            -Email $review.Email `
            -Action "MISSING_ACCESS_REMEDIATION" `
            -Target $group `
            -Result "FAILED" `
            -Reason $_.Exception.Message

        throw
    }
}

Write-Host ""
Write-Host "REMEDIATION COMPLETE"