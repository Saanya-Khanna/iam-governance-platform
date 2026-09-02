function Write-AuditLog {

    param (
        [Parameter(Mandatory)]
        [string]$Email,

        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [string]$Result,

        [string]$Reason = ""
    )

    $logPath = "./logs/audit.csv"

    $record = [PSCustomObject]@{
        Timestamp = (Get-Date).ToString("o")
        Email     = $Email
        Action    = $Action
        Target    = $Target
        Result    = $Result
        Reason    = $Reason
    }

    if (Test-Path $logPath) {

        $record |
            Export-Csv $logPath -Append -NoTypeInformation

    }
    else {

        $record |
            Export-Csv $logPath -NoTypeInformation

    }
}

Export-ModuleMember -Function Write-AuditLog