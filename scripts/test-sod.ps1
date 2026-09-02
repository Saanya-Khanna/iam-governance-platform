Import-Module "./modules/SoD.psm1" -Force

$sodConfig = Get-Content "./config/sod-rules.json" |
    ConvertFrom-Json

$testGroups = @(
    "corp-basic",
    "accounts-payable-create",
    "payment-approve"
)

$violations = Test-SoDConflict `
    -Groups $testGroups `
    -SoDConfig $sodConfig

if ($violations.Count -eq 0) {
    Write-Host "No SoD violations found."
}
else {

    Write-Host "SoD violations found:"

    foreach ($violation in $violations) {

        Write-Host ""
        Write-Host "Conflict:"
        Write-Host "- $($violation.GroupA)"
        Write-Host "- $($violation.GroupB)"
        Write-Host "Reason: $($violation.Reason)"
    }
}