Import-Module "./modules/RBAC.psm1" -Force
Import-Module "./modules/Policy.psm1" -Force
Import-Module "./modules/SoD.psm1" -Force
Import-Module "./modules/AccessReview.psm1" -Force


$employees = Import-Csv "./data/hr-employees.csv"

$roleMapping = Get-Content "./config/role-mapping.json" |
    ConvertFrom-Json

$rbac = Get-Content "./config/rbac.json" |
    ConvertFrom-Json

$policies = Get-Content "./config/policies.json" |
    ConvertFrom-Json

$sod = Get-Content "./config/sod-rules.json" |
    ConvertFrom-Json


$employee = $employees[0]


Write-Host ""
Write-Host "ACCESS REVIEW TEST"
Write-Host "=================="
Write-Host "Employee:" $employee.Email
Write-Host ""


# ------------------------------------
# TEST 1: Correct access
# ------------------------------------

Write-Host "TEST 1 - COMPLIANT"
Write-Host "------------------"

$result = Test-UserAccess `
    -Employee $employee `
    -ActualGroups @(
        "corp-basic",
        "content-access"
    ) `
    -RoleMapping $roleMapping `
    -RbacConfig $rbac `
    -PolicyConfig $policies `
    -SoDConfig $sod

$result | Format-List


# ------------------------------------
# TEST 2: Missing access
# ------------------------------------

Write-Host ""
Write-Host "TEST 2 - MISSING ACCESS"
Write-Host "-----------------------"

$result = Test-UserAccess `
    -Employee $employee `
    -ActualGroups @(
        "corp-basic"
    ) `
    -RoleMapping $roleMapping `
    -RbacConfig $rbac `
    -PolicyConfig $policies `
    -SoDConfig $sod

$result | Format-List


# ------------------------------------
# TEST 3: Excess access
# ------------------------------------

Write-Host ""
Write-Host "TEST 3 - EXCESS ACCESS"
Write-Host "----------------------"

$result = Test-UserAccess `
    -Employee $employee `
    -ActualGroups @(
        "corp-basic",
        "content-access",
        "finance-read"
    ) `
    -RoleMapping $roleMapping `
    -RbacConfig $rbac `
    -PolicyConfig $policies `
    -SoDConfig $sod

$result | Format-List


# ------------------------------------
# TEST 4: SoD violation
# ------------------------------------

Write-Host ""
Write-Host "TEST 4 - SOD VIOLATION"
Write-Host "----------------------"

$result = Test-UserAccess `
    -Employee $employee `
    -ActualGroups @(
        "corp-basic",
        "content-access",
        "accounts-payable-create",
        "payment-approve"
    ) `
    -RoleMapping $roleMapping `
    -RbacConfig $rbac `
    -PolicyConfig $policies `
    -SoDConfig $sod

$result | Format-List