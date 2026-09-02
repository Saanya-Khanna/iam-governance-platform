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
    Where-Object {
        $_.Email -eq $Email
    } |
    Select-Object -First 1


if (-not $review) {
    throw "No access review record found for: $Email"
}


Write-Host ""
Write-Host "ACCESS REMEDIATION"
Write-Host "=================="
Write-Host "Email:" $review.Email
Write-Host "Finding:" $review.Status
Write-Host ""


if ($review.Status -ne "EXCESS_ACCESS") {
    throw "This script only automatically remediates EXCESS_ACCESS findings."
}


$excessGroups = @(
    $review.ExcessAccess -split ";" |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        }
)


if ($excessGroups.Count -eq 0) {
    throw "Review is marked EXCESS_ACCESS but no excess groups were listed."
}


$oktaUser = Get-OktaUserByEmail `
    -Email $review.Email


if (-not $oktaUser) {
    throw "Okta user not found: $($review.Email)"
}


Write-Host "Groups approved for removal:"
foreach ($group in $excessGroups) {
    Write-Host "-" $group
}


foreach ($group in $excessGroups) {

    try {

        Remove-OktaUserFromGroup `
            -UserId $oktaUser.id `
            -GroupName $group


        Write-AuditLog `
            -Email $review.Email `
            -Action "ACCESS_REMEDIATION" `
            -Target $group `
            -Result "SUCCESS" `
            -Reason "Removed excess access identified during certification."
    }
    catch {

        Write-AuditLog `
            -Email $review.Email `
            -Action "ACCESS_REMEDIATION" `
            -Target $group `
            -Result "FAILED" `
            -Reason $_.Exception.Message

        throw
    }
}


Write-Host ""
Write-Host "REMEDIATION COMPLETE"