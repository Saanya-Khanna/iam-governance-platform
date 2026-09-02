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


# Same employee we already provisioned into Okta
$oldEmployee = $employees[0]


# Clone the employee so we can simulate a role change
$newEmployee = $oldEmployee.PSObject.Copy()

$newEmployee.JobTitle = "Broadcast engineer"
$newEmployee.Department = "Engineering / IT"
$newEmployee.RoleFamily = "Engineering / IT"


Write-Host ""
Write-Host "MOVER ACCESS CALCULATION"
Write-Host "------------------------"

$result = Invoke-Mover `
    -OldEmployee $oldEmployee `
    -NewEmployee $newEmployee `
    -RoleMapping $roleMapping `
    -RbacConfig $rbac `
    -PolicyConfig $policies


Write-Host "Employee:" $result.Email
Write-Host "Old Role Family:" $result.OldRoleFamily
Write-Host "New Role Family:" $result.NewRoleFamily
Write-Host "Status:" $result.Status


Write-Host ""
Write-Host "GROUPS TO ADD"
Write-Host "-------------"

$result.GroupsToAdd |
    ForEach-Object {
        Write-Host "-" $_
    }


Write-Host ""
Write-Host "GROUPS TO REMOVE"
Write-Host "----------------"

$result.GroupsToRemove |
    ForEach-Object {
        Write-Host "-" $_
    }


if ($result.Status -ne "ACCESS_CHANGE_REQUIRED") {
    throw "Mover event is not ready for access reconciliation."
}


Write-Host ""
Write-Host "FINDING OKTA USER"
Write-Host "-----------------"

$oktaUser = Get-OktaUserByEmail `
    -Email $oldEmployee.Email

if (-not $oktaUser) {
    throw "Okta user not found: $($oldEmployee.Email)"
}

Write-Host "Okta user found."
Write-Host "Okta ID:" $oktaUser.id


Write-Host ""
Write-Host "REMOVING OLD ACCESS"
Write-Host "-------------------"

foreach ($group in $result.GroupsToRemove) {

    Remove-OktaUserFromGroup `
        -UserId $oktaUser.id `
        -GroupName $group
}


Write-Host ""
Write-Host "ADDING NEW ACCESS"
Write-Host "-----------------"

foreach ($group in $result.GroupsToAdd) {

    Add-OktaUserToGroup `
        -UserId $oktaUser.id `
        -GroupName $group
}


Write-Host ""
Write-Host "VERIFYING CURRENT OKTA ACCESS"
Write-Host "-----------------------------"

$currentGroups = Get-OktaUserGroups `
    -UserId $oktaUser.id

$currentGroups |
    Select-Object `
        @{Name="GroupName"; Expression={$_.profile.name}},
        id,
        type |
    Format-Table


Write-Host ""
Write-Host "MOVER COMPLETE"
Write-Host "--------------"

Write-Host "Employee:" $result.Email
Write-Host "Old Role:" $result.OldRoleFamily
Write-Host "New Role:" $result.NewRoleFamily
Write-Host "Added:" ($result.GroupsToAdd -join ", ")
Write-Host "Removed:" ($result.GroupsToRemove -join ", ")