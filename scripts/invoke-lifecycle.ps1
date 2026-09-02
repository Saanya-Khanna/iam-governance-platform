param (
    [Parameter(Mandatory)]
    [ValidateSet("Joiner", "Mover", "Leaver")]
    [string]$EventType,

    [Parameter(Mandatory)]
    [string]$EmployeeID,

    [string]$NewJobTitle
)


Import-Module "./modules/RBAC.psm1" -Force
Import-Module "./modules/Policy.psm1" -Force
Import-Module "./modules/JML.psm1" -Force
Import-Module "./modules/Okta.psm1" -Force
Import-Module "./modules/Logging.psm1" -Force


# -----------------------------
# Load configuration and HR data
# -----------------------------

$employees = Import-Csv "./data/hr-employees.csv"

$roleMapping = Get-Content "./config/role-mapping.json" |
    ConvertFrom-Json

$rbac = Get-Content "./config/rbac.json" |
    ConvertFrom-Json

$policies = Get-Content "./config/policies.json" |
    ConvertFrom-Json


# -----------------------------
# Find employee
# -----------------------------

$employee = $employees |
    Where-Object {
        $_.EmployeeID -eq $EmployeeID
    } |
    Select-Object -First 1


if (-not $employee) {
    throw "Employee not found: $EmployeeID"
}


Write-Host ""
Write-Host "IAM LIFECYCLE EVENT"
Write-Host "==================="
Write-Host "Event:" $EventType
Write-Host "Employee ID:" $employee.EmployeeID
Write-Host "Email:" $employee.Email
Write-Host ""


# =========================================================
# JOINER
# =========================================================

if ($EventType -eq "Joiner") {

    $result = Invoke-Joiner `
        -Employee $employee `
        -RoleMapping $roleMapping `
        -RbacConfig $rbac `
        -PolicyConfig $policies


    if ($result.Status -ne "READY_TO_PROVISION") {

        Write-AuditLog `
            -Email $employee.Email `
            -Action "JOINER" `
            -Target "Okta" `
            -Result "FAILED" `
            -Reason $result.Status

        throw "Joiner failed policy/RBAC evaluation: $($result.Status)"
    }


    Write-Host "Role Family:" $result.RoleFamily
    Write-Host "Approved Groups:" ($result.ApprovedGroups -join ", ")


    $oktaUser = New-OktaUser `
        -FirstName $employee.FirstName `
        -LastName $employee.LastName `
        -Email $employee.Email


    foreach ($group in $result.ApprovedGroups) {

        Add-OktaUserToGroup `
            -UserId $oktaUser.id `
            -GroupName $group
    }


    Write-AuditLog `
        -Email $employee.Email `
        -Action "JOINER" `
        -Target "Okta" `
        -Result "SUCCESS" `
        -Reason "Provisioned groups: $($result.ApprovedGroups -join ', ')"


    Write-Host ""
    Write-Host "JOINER COMPLETE"
}


# =========================================================
# MOVER
# =========================================================

elseif ($EventType -eq "Mover") {

    if (-not $NewJobTitle) {
        throw "Mover events require -NewJobTitle."
    }


    # Verify the requested job title exists in our role model.

    $newRoleFamily = $roleMapping.$NewJobTitle

    if (-not $newRoleFamily) {
        throw "Job title is not mapped: $NewJobTitle"
    }


    # Create an updated copy without modifying the source CSV.

    $newEmployee = $employee.PSObject.Copy()

    $newEmployee.JobTitle = $NewJobTitle
    $newEmployee.RoleFamily = $newRoleFamily
    $newEmployee.Department = $newRoleFamily


    $result = Invoke-Mover `
        -OldEmployee $employee `
        -NewEmployee $newEmployee `
        -RoleMapping $roleMapping `
        -RbacConfig $rbac `
        -PolicyConfig $policies


    if ($result.Status -ne "ACCESS_CHANGE_REQUIRED") {

        Write-AuditLog `
            -Email $employee.Email `
            -Action "MOVER" `
            -Target "Okta" `
            -Result "FAILED" `
            -Reason $result.Status

        throw "Mover calculation failed: $($result.Status)"
    }


    $oktaUser = Get-OktaUserByEmail `
        -Email $employee.Email


    if (-not $oktaUser) {
        throw "Okta user not found: $($employee.Email)"
    }


    Write-Host "Old Role:" $result.OldRoleFamily
    Write-Host "New Role:" $result.NewRoleFamily

    Write-Host "Groups to add:" ($result.GroupsToAdd -join ", ")
    Write-Host "Groups to remove:" ($result.GroupsToRemove -join ", ")


    foreach ($group in $result.GroupsToRemove) {

        Remove-OktaUserFromGroup `
            -UserId $oktaUser.id `
            -GroupName $group
    }


    foreach ($group in $result.GroupsToAdd) {

        Add-OktaUserToGroup `
            -UserId $oktaUser.id `
            -GroupName $group
    }


    Write-AuditLog `
        -Email $employee.Email `
        -Action "MOVER" `
        -Target "Okta" `
        -Result "SUCCESS" `
        -Reason "Added: $($result.GroupsToAdd -join ', '); Removed: $($result.GroupsToRemove -join ', ')"


    Write-Host ""
    Write-Host "MOVER COMPLETE"
}


# =========================================================
# LEAVER
# =========================================================

elseif ($EventType -eq "Leaver") {

    $result = Invoke-Leaver `
        -Employee $employee `
        -RoleMapping $roleMapping `
        -RbacConfig $rbac


    $oktaUser = Get-OktaUserByEmail `
        -Email $employee.Email


    if (-not $oktaUser) {
        throw "Okta user not found: $($employee.Email)"
    }


    # Read actual Okta state instead of relying only
    # on HR-derived access.

    $currentGroups = Get-OktaUserGroups `
        -UserId $oktaUser.id


    $currentGroupNames = @(
        $currentGroups |
            ForEach-Object {
                $_.profile.name
            }
    )


    # Build list of every group managed by our RBAC engine.

    $managedGroups = @()

    foreach ($role in $rbac.PSObject.Properties) {
        $managedGroups += @($role.Value.groups)
    }

    $managedGroups = $managedGroups |
        Sort-Object -Unique


    $groupsToRemove = @(
        $currentGroupNames |
            Where-Object {
                $_ -in $managedGroups
            }
    )


    Write-Host "Managed groups to remove:"
    
    foreach ($group in $groupsToRemove) {
        Write-Host "-" $group
    }


    foreach ($group in $groupsToRemove) {

        Remove-OktaUserFromGroup `
            -UserId $oktaUser.id `
            -GroupName $group
    }


    if ($result.DisableAccount) {

        Disable-OktaUser `
            -UserId $oktaUser.id
    }


    Write-AuditLog `
        -Email $employee.Email `
        -Action "LEAVER" `
        -Target "Okta" `
        -Result "SUCCESS" `
        -Reason "Removed: $($groupsToRemove -join ', '); Account deactivated."


    Write-Host ""
    Write-Host "LEAVER COMPLETE"
}