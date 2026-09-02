function Test-SoDConflict {

    param (
        [Parameter(Mandatory)]
        [array]$Groups,

        [Parameter(Mandatory)]
        $SoDConfig
    )

    $violations = @()

    foreach ($rule in $SoDConfig.conflicts) {

        if (
            ($Groups -contains $rule.groupA) -and
            ($Groups -contains $rule.groupB)
        ) {

            $violations += [PSCustomObject]@{
                GroupA = $rule.groupA
                GroupB = $rule.groupB
                Reason = $rule.reason
            }
        }
    }

    return $violations
}

Export-ModuleMember -Function Test-SoDConflict