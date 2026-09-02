function Test-UserAccess {
    param (
        [Parameter(Mandatory)]
        $Employee,

        [Parameter(Mandatory)]
        [array]$ActualGroups,

        [Parameter(Mandatory)]
        $RoleMapping,

        [Parameter(Mandatory)]
        $RbacConfig,

        [Parameter(Mandatory)]
        $PolicyConfig,

        [Parameter(Mandatory)]
        $SoDConfig
    )

    # Determine expected access from RBAC
    $requiredAccess = Get-RequiredAccess `
        -Employee $Employee `
        -RoleMapping $RoleMapping `
        -RbacConfig $RbacConfig

    if ($requiredAccess.Status -ne "SUCCESS") {
        return [PSCustomObject]@{
            EmployeeID    = $Employee.EmployeeID
            Email         = $Employee.Email
            RoleFamily    = $requiredAccess.RoleFamily
            ExpectedGroups = ""
            ActualGroups   = ($ActualGroups -join ";")
            MissingAccess  = ""
            ExcessAccess   = ""
            SoDViolations  = ""
            Status         = "REVIEW_REQUIRED"
        }
    }


    # Apply policy controls to expected RBAC access
    $policyResult = Test-AccessPolicy `
        -Groups $requiredAccess.Groups `
        -PolicyConfig $PolicyConfig

    $expectedGroups = @(
        $policyResult.ApprovedGroups |
        Sort-Object -Unique
    )

    $actualGroups = @(
        $ActualGroups |
        Sort-Object -Unique
    )


    # Expected but not currently assigned
    $missingAccess = @(
        $expectedGroups |
        Where-Object {
            $_ -notin $actualGroups
        }
    )


    # Currently assigned but not expected
    $excessAccess = @(
        $actualGroups |
        Where-Object {
            $_ -notin $expectedGroups
        }
    )


    # Check current access for SoD conflicts
    $sodViolations = @(
        Test-SoDConflict `
            -Groups $actualGroups `
            -SoDConfig $SoDConfig
    )


    # Determine review status
    if ($sodViolations.Count -gt 0) {
        $status = "SOD_VIOLATION"
    }
    elseif ($excessAccess.Count -gt 0) {
        $status = "EXCESS_ACCESS"
    }
    elseif ($missingAccess.Count -gt 0) {
        $status = "MISSING_ACCESS"
    }
    else {
        $status = "COMPLIANT"
    }


    $sodText = @(
        $sodViolations |
        ForEach-Object {
            "$($_.GroupA) <-> $($_.GroupB)"
        }
    )


    return [PSCustomObject]@{
        EmployeeID     = $Employee.EmployeeID
        Email          = $Employee.Email
        RoleFamily     = $requiredAccess.RoleFamily

        ExpectedGroups = ($expectedGroups -join ";")
        ActualGroups   = ($actualGroups -join ";")

        MissingAccess  = ($missingAccess -join ";")
        ExcessAccess   = ($excessAccess -join ";")
        SoDViolations  = ($sodText -join ";")

        Status          = $status
    }
}


Export-ModuleMember -Function Test-UserAccess