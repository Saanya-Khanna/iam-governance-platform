Import-Module "./modules/RBAC.psm1" -Force
Import-Module "./modules/JML.psm1" -Force
Import-Module "./modules/Okta.psm1" -Force

$employees = Import-Csv "./data/hr-employees.csv"

$roleMapping = Get-Content "./config/role-mapping.json" |
    ConvertFrom-Json

$rbac = Get-Content "./config/rbac.json" |
    ConvertFrom-Json


# Same employee used for Joiner/Mover testing
$employee = $employees[0]


Write-Host ""
Write-Host "LEAVER ACCESS CALCULATION"
Write-Host "-------------------------"

$result = Invoke-Leaver `
    -Employee $employee `
    -RoleMapping $roleMapping `
    -RbacConfig $rbac


Write-Host "Employee:" $result.Email
Write-Host "Status:" $result.Status
Write-Host "Disable Account:" $result.DisableAccount

Write-Host ""
Write-Host "GROUPS TO REMOVE"
Write-Host "----------------"

$result.GroupsToRemove |
    ForEach-Object {
        Write-Host "-" $_
    }


if ($result.Status -ne "READY_TO_DEPROVISION") {
    throw "Employee is not ready for deprovisioning."
}


Write-Host ""
Write-Host "FINDING OKTA USER"
Write-Host "-----------------"

$oktaUser = Get-OktaUserByEmail `
    -Email $employee.Email

if (-not $oktaUser) {
    throw "Okta user not found: $($employee.Email)"
}

Write-Host "Okta ID:" $oktaUser.id
Write-Host "Current Status:" $oktaUser.status


Write-Host ""
Write-Host "REMOVING MANAGED ACCESS"
Write-Host "-----------------------"

# Get the user's actual current Okta groups.
$currentGroups = Get-OktaUserGroups `
    -UserId $oktaUser.id

$currentGroupNames = @(
    $currentGroups |
        ForEach-Object { $_.profile.name }
)

# Remove RBAC-managed groups currently assigned to the user.
$managedGroups = @()

foreach ($role in $rbac.PSObject.Properties) {
    $managedGroups += @($role.Value.groups)
}

$managedGroups = $managedGroups |
    Sort-Object -Unique

$groupsToRemove = @(
    $currentGroupNames |
        Where-Object { $_ -in $managedGroups }
)

foreach ($group in $groupsToRemove) {

    Remove-OktaUserFromGroup `
        -UserId $oktaUser.id `
        -GroupName $group
}


Write-Host ""
Write-Host "DEACTIVATING ACCOUNT"
Write-Host "--------------------"

if ($result.DisableAccount) {

    Disable-OktaUser `
        -UserId $oktaUser.id
}


Write-Host ""
Write-Host "VERIFYING ACCOUNT"
Write-Host "-----------------"

$updatedUser = Get-OktaUserByEmail `
    -Email $employee.Email

if ($updatedUser) {
    Write-Host "Status:" $updatedUser.status
}
else {
    Write-Host "Unable to retrieve user after deactivation."
}


Write-Host ""
Write-Host "LEAVER COMPLETE"
Write-Host "---------------"

Write-Host "Employee:" $employee.Email
Write-Host "Removed managed groups:" ($groupsToRemove -join ", ")
Write-Host "Account deactivated:" $result.DisableAccount