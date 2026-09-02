Import-Module "./modules/RBAC.psm1" -Force
Import-Module "./modules/Policy.psm1" -Force
Import-Module "./modules/JML.psm1" -Force
Import-Module "./modules/Okta.psm1" -Force

$employees = Import-Csv "./data/hr-employees.csv"

$roleMapping = Get-Content "./config/role-mapping.json" |
    ConvertFrom-Json

$rbac = Get-Content "./config/rbac.json" |
    ConvertFrom-Json

$policies = Get-Content "./config/policies.json" |
    ConvertFrom-Json


# Use the first employee in the synthetic HR dataset
$employee = $employees[0]


Write-Host ""
Write-Host "JOINER ACCESS CALCULATION"
Write-Host "-------------------------"

$result = Invoke-Joiner `
    -Employee $employee `
    -RoleMapping $roleMapping `
    -RbacConfig $rbac `
    -PolicyConfig $policies


Write-Host "Employee:" $employee.Email
Write-Host "Role Family:" $result.RoleFamily
Write-Host "Status:" $result.Status

Write-Host ""
Write-Host "Approved Groups:"

$result.ApprovedGroups |
    ForEach-Object {
        Write-Host "-" $_
    }


Write-Host ""
Write-Host "Denied Groups:"

$result.DeniedGroups |
    ForEach-Object {
        Write-Host "-" $_
    }


if ($result.Status -ne "READY_TO_PROVISION") {
    throw "Employee is not approved for provisioning."
}


Write-Host ""
Write-Host "CREATING OKTA USER"
Write-Host "------------------"

$oktaUser = New-OktaUser `
    -FirstName $employee.FirstName `
    -LastName $employee.LastName `
    -Email $employee.Email


if (-not $oktaUser) {
    throw "Okta user creation returned no user."
}

if (-not $oktaUser.id) {
    throw "Okta user creation returned no user ID."
}


Write-Host ""
Write-Host "Okta User ID:" $oktaUser.id
Write-Host "Okta Status:" $oktaUser.status


Write-Host ""
Write-Host "ASSIGNING RBAC GROUPS"
Write-Host "---------------------"

foreach ($group in $result.ApprovedGroups) {

    Add-OktaUserToGroup `
        -UserId $oktaUser.id `
        -GroupName $group
}


Write-Host ""
Write-Host "PROVISIONING COMPLETE"
Write-Host "---------------------"

Write-Host "Employee:" $employee.Email
Write-Host "Okta ID:" $oktaUser.id
Write-Host "Okta Status:" $oktaUser.status
Write-Host "Groups:" ($result.ApprovedGroups -join ", ")