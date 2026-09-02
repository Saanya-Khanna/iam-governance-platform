function Test-AccessPolicy {

    param (
        [Parameter(Mandatory)]
        [array]$Groups,

        [Parameter(Mandatory)]
        $PolicyConfig
    )

    $approvedGroups = @()
    $deniedGroups = @()

    foreach ($group in $Groups) {

        $restriction = $PolicyConfig.restrictedGroups |
            Where-Object { $_.group -eq $group }

        if ($restriction -and
            $restriction.automaticAssignment -eq $false) {

            $deniedGroups += [PSCustomObject]@{
                Group  = $group
                Reason = $restriction.reason
            }

        }
        else {

            $approvedGroups += $group

        }
    }

    return [PSCustomObject]@{
        ApprovedGroups = $approvedGroups
        DeniedGroups   = $deniedGroups
    }
}

Export-ModuleMember -Function Test-AccessPolicy