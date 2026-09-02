function Get-RequiredAccess {
    param (
        [Parameter(Mandatory)]
        $Employee,

        [Parameter(Mandatory)]
        $RoleMapping,

        [Parameter(Mandatory)]
        $RbacConfig
    )

    # Support both the original HR source and enriched IAM dataset
    $jobTitle = if ($Employee.JobTitle) {
    $Employee.JobTitle
    }
    else {
    $Employee.'Job Title'
    }

    $roleFamily = $RoleMapping.$jobTitle

    if (-not $roleFamily) {
        return [PSCustomObject]@{
            Email      = $Employee.Email
            JobTitle   = $jobTitle
            RoleFamily = "UNMAPPED"
            Groups     = @()
            Status     = "UNMAPPED_ROLE"
        }
    }

    $access = $RbacConfig.$roleFamily

    if (-not $access) {
        return [PSCustomObject]@{
            Email      = $Employee.Email
            JobTitle   = $jobTitle
            RoleFamily = $roleFamily
            Groups     = @()
            Status     = "NO_RBAC_MAPPING"
        }
    }

    return [PSCustomObject]@{
        Email      = $Employee.Email
        JobTitle   = $jobTitle
        RoleFamily = $roleFamily
        Groups     = @($access.groups)
        Status     = "SUCCESS"
    }
}

Export-ModuleMember -Function Get-RequiredAccess