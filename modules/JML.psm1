function Invoke-Joiner {

    param (
        [Parameter(Mandatory)]
        $Employee,

        [Parameter(Mandatory)]
        $RoleMapping,

        [Parameter(Mandatory)]
        $RbacConfig,

        [Parameter(Mandatory)]
        $PolicyConfig
    )

    $access = Get-RequiredAccess `
        -Employee $Employee `
        -RoleMapping $RoleMapping `
        -RbacConfig $RbacConfig

    if ($access.Status -ne "SUCCESS") {

        return [PSCustomObject]@{
            EventType       = "JOINER"
            EmployeeID      = $Employee.EmployeeID
            Email           = $Employee.Email
            RoleFamily      = $access.RoleFamily
            ApprovedGroups  = @()
            DeniedGroups    = @()
            Status          = $access.Status
        }
    }

    $policyResult = Test-AccessPolicy `
        -Groups $access.Groups `
        -PolicyConfig $PolicyConfig

    return [PSCustomObject]@{
        EventType       = "JOINER"
        EmployeeID      = $Employee.EmployeeID
        Email           = $Employee.Email
        RoleFamily      = $access.RoleFamily
        ApprovedGroups  = @($policyResult.ApprovedGroups)
        DeniedGroups    = @(
            $policyResult.DeniedGroups |
            ForEach-Object { $_.Group }
        )
        Status          = "READY_TO_PROVISION"
    }
}


function Invoke-Mover {

    param (
        [Parameter(Mandatory)]
        $OldEmployee,

        [Parameter(Mandatory)]
        $NewEmployee,

        [Parameter(Mandatory)]
        $RoleMapping,

        [Parameter(Mandatory)]
        $RbacConfig,

        [Parameter(Mandatory)]
        $PolicyConfig
    )

    $oldAccess = Get-RequiredAccess `
        -Employee $OldEmployee `
        -RoleMapping $RoleMapping `
        -RbacConfig $RbacConfig

    $newAccess = Get-RequiredAccess `
        -Employee $NewEmployee `
        -RoleMapping $RoleMapping `
        -RbacConfig $RbacConfig

    if ($newAccess.Status -ne "SUCCESS") {

        return [PSCustomObject]@{
            EventType       = "MOVER"
            EmployeeID      = $NewEmployee.EmployeeID
            Email           = $NewEmployee.Email
            OldRoleFamily   = $oldAccess.RoleFamily
            NewRoleFamily   = $newAccess.RoleFamily
            GroupsToAdd     = @()
            GroupsToRemove  = @()
            Status          = $newAccess.Status
        }
    }

    $policyResult = Test-AccessPolicy `
        -Groups $newAccess.Groups `
        -PolicyConfig $PolicyConfig

    $oldGroups = @($oldAccess.Groups)
    $newGroups = @($policyResult.ApprovedGroups)

    $groupsToAdd = @(
        $newGroups |
        Where-Object { $_ -notin $oldGroups }
    )

    $groupsToRemove = @(
        $oldGroups |
        Where-Object { $_ -notin $newGroups }
    )

    return [PSCustomObject]@{
        EventType       = "MOVER"
        EmployeeID      = $NewEmployee.EmployeeID
        Email           = $NewEmployee.Email
        OldRoleFamily   = $oldAccess.RoleFamily
        NewRoleFamily   = $newAccess.RoleFamily
        GroupsToAdd     = $groupsToAdd
        GroupsToRemove  = $groupsToRemove
        Status          = "ACCESS_CHANGE_REQUIRED"
    }
}


function Invoke-Leaver {

    param (
        [Parameter(Mandatory)]
        $Employee,

        [Parameter(Mandatory)]
        $RoleMapping,

        [Parameter(Mandatory)]
        $RbacConfig
    )

    $access = Get-RequiredAccess `
        -Employee $Employee `
        -RoleMapping $RoleMapping `
        -RbacConfig $RbacConfig

    return [PSCustomObject]@{
        EventType       = "LEAVER"
        EmployeeID      = $Employee.EmployeeID
        Email           = $Employee.Email
        GroupsToRemove  = @($access.Groups)
        DisableAccount  = $true
        Status          = "READY_TO_DEPROVISION"
    }
}


Export-ModuleMember -Function `
    Invoke-Joiner,
    Invoke-Mover,
    Invoke-Leaver