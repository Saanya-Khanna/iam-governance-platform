$ErrorActionPreference = "Stop"

Import-Module "./modules/RBAC.psm1" -Force
Import-Module "./modules/Policy.psm1" -Force
Import-Module "./modules/SoD.psm1" -Force
Import-Module "./modules/AccessReview.psm1" -Force

Write-Host ""
Write-Host "IAM PLATFORM VALIDATION"
Write-Host "======================="
Write-Host ""

$passed = 0
$failed = 0

function Test-Result {
    param (
        [string]$Name,
        [bool]$Condition
    )

    if ($Condition) {
        Write-Host "[PASS] $Name"
        $script:passed++
    }
    else {
        Write-Host "[FAIL] $Name"
        $script:failed++
    }
}


# --------------------------------
# Load configuration
# --------------------------------

$employees = Import-Csv "./data/hr-employees.csv"

$roleMapping = Get-Content "./config/role-mapping.json" |
    ConvertFrom-Json

$rbac = Get-Content "./config/rbac.json" |
    ConvertFrom-Json

$policies = Get-Content "./config/policies.json" |
    ConvertFrom-Json

$sod = Get-Content "./config/sod-rules.json" |
    ConvertFrom-Json


# --------------------------------
# 1. HR dataset
# --------------------------------

Test-Result `
    -Name "HR dataset contains 10,000 employees" `
    -Condition ($employees.Count -eq 10000)


# --------------------------------
# 2. RBAC mapping
# --------------------------------

$employee = $employees[0]

$access = Get-RequiredAccess `
    -Employee $employee `
    -RoleMapping $roleMapping `
    -RbacConfig $rbac

Test-Result `
    -Name "Employee resolves to RBAC role" `
    -Condition ($access.Status -eq "SUCCESS")

Test-Result `
    -Name "RBAC returns at least one group" `
    -Condition ($access.Groups.Count -gt 0)


# --------------------------------
# 3. Policy engine
# --------------------------------

$policyTest = Test-AccessPolicy `
    -Groups @(
        "corp-basic",
        "finance-admin"
    ) `
    -PolicyConfig $policies

Test-Result `
    -Name "Standard access passes policy" `
    -Condition ($policyTest.ApprovedGroups -contains "corp-basic")

Test-Result `
    -Name "Privileged access requires approval" `
    -Condition (
        $policyTest.DeniedGroups.Group -contains "finance-admin"
    )


# --------------------------------
# 4. SoD
# --------------------------------

$sodTest = @(
    Test-SoDConflict `
        -Groups @(
            "accounts-payable-create",
            "payment-approve"
        ) `
        -SoDConfig $sod
)

Test-Result `
    -Name "SoD conflict detected" `
    -Condition ($sodTest.Count -gt 0)


# --------------------------------
# 5. Access review - compliant
# --------------------------------

$expectedGroups = @($access.Groups)

$review = Test-UserAccess `
    -Employee $employee `
    -ActualGroups $expectedGroups `
    -RoleMapping $roleMapping `
    -RbacConfig $rbac `
    -PolicyConfig $policies `
    -SoDConfig $sod

Test-Result `
    -Name "Correct access classified COMPLIANT" `
    -Condition ($review.Status -eq "COMPLIANT")


# --------------------------------
# 6. Missing access
# --------------------------------

$missingReview = Test-UserAccess `
    -Employee $employee `
    -ActualGroups @("corp-basic") `
    -RoleMapping $roleMapping `
    -RbacConfig $rbac `
    -PolicyConfig $policies `
    -SoDConfig $sod

Test-Result `
    -Name "Missing entitlement detected" `
    -Condition (
        $missingReview.Status -eq "MISSING_ACCESS"
    )


# --------------------------------
# 7. Excess access
# --------------------------------

$excessGroups = @($expectedGroups) + "finance-read"

$excessReview = Test-UserAccess `
    -Employee $employee `
    -ActualGroups $excessGroups `
    -RoleMapping $roleMapping `
    -RbacConfig $rbac `
    -PolicyConfig $policies `
    -SoDConfig $sod

Test-Result `
    -Name "Excess entitlement detected" `
    -Condition (
        $excessReview.Status -eq "EXCESS_ACCESS"
    )


# --------------------------------
# 8. SoD review severity
# --------------------------------

$sodReviewGroups = @($expectedGroups) +
    "accounts-payable-create" +
    "payment-approve"

$sodReview = Test-UserAccess `
    -Employee $employee `
    -ActualGroups $sodReviewGroups `
    -RoleMapping $roleMapping `
    -RbacConfig $rbac `
    -PolicyConfig $policies `
    -SoDConfig $sod

Test-Result `
    -Name "SoD violation takes review priority" `
    -Condition (
        $sodReview.Status -eq "SOD_VIOLATION"
    )


# --------------------------------
# Results
# --------------------------------

Write-Host ""
Write-Host "VALIDATION SUMMARY"
Write-Host "=================="
Write-Host "Passed:" $passed
Write-Host "Failed:" $failed

if ($failed -gt 0) {
    Write-Host ""
    throw "$failed platform validation test(s) failed."
}

Write-Host ""
Write-Host "ALL PLATFORM VALIDATIONS PASSED"