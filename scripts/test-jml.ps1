Import-Module "./modules/RBAC.psm1" -Force
Import-Module "./modules/Policy.psm1" -Force
Import-Module "./modules/JML.psm1" -Force

$employees = Import-Csv "./data/hr-employees.csv"

$roleMapping = Get-Content "./config/role-mapping.json" |
    ConvertFrom-Json

$rbac = Get-Content "./config/rbac.json" |
    ConvertFrom-Json

$policies = Get-Content "./config/policies.json" |
    ConvertFrom-Json

$employee = $employees[0]

# -------------------------
# JOINER TEST
# -------------------------

$result = Invoke-Joiner `
    -Employee $employee `
    -RoleMapping $roleMapping `
    -RbacConfig $rbac `
    -PolicyConfig $policies

Write-Host ""
Write-Host "JOINER TEST"
Write-Host "-----------"
Write-Host "Employee ID:" $result.EmployeeID
Write-Host "Email:" $result.Email
Write-Host "Role Family:" $result.RoleFamily
Write-Host "Status:" $result.Status

Write-Host ""
Write-Host "Groups to provision:"

foreach ($group in $result.ApprovedGroups) {
    Write-Host "- $group"
}

Write-Host ""
Write-Host "Denied groups:"

foreach ($group in $result.DeniedGroups) {
    Write-Host "- $group"
}


# -------------------------
# MOVER TEST
# -------------------------

$oldEmployee = $employees[0].PSObject.Copy()
$newEmployee = $employees[0].PSObject.Copy()

$newEmployee.JobTitle = "Broadcast engineer"
$newEmployee.Department = "Engineering / IT"
$newEmployee.RoleFamily = "Engineering / IT"

$moverResult = Invoke-Mover `
    -OldEmployee $oldEmployee `
    -NewEmployee $newEmployee `
    -RoleMapping $roleMapping `
    -RbacConfig $rbac `
    -PolicyConfig $policies

Write-Host ""
Write-Host "MOVER TEST"
Write-Host "----------"
Write-Host "Employee ID:" $moverResult.EmployeeID
Write-Host "Email:" $moverResult.Email
Write-Host "Old role:" $moverResult.OldRoleFamily
Write-Host "New role:" $moverResult.NewRoleFamily
Write-Host "Status:" $moverResult.Status

Write-Host ""
Write-Host "Groups to ADD:"

foreach ($group in $moverResult.GroupsToAdd) {
    Write-Host "- $group"
}

Write-Host ""
Write-Host "Groups to REMOVE:"

foreach ($group in $moverResult.GroupsToRemove) {
    Write-Host "- $group"
}


# -------------------------
# LEAVER TEST
# -------------------------

$leaverResult = Invoke-Leaver `
    -Employee $employee `
    -RoleMapping $roleMapping `
    -RbacConfig $rbac

Write-Host ""
Write-Host "LEAVER TEST"
Write-Host "-----------"
Write-Host "Employee ID:" $leaverResult.EmployeeID
Write-Host "Email:" $leaverResult.Email
Write-Host "Disable account:" $leaverResult.DisableAccount
Write-Host "Status:" $leaverResult.Status

Write-Host ""
Write-Host "Groups to REMOVE:"

foreach ($group in $leaverResult.GroupsToRemove) {
    Write-Host "- $group"
}