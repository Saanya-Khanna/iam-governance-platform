param (
    [string]$InputFile = "./data/lifecycle-events.csv"
)

if (-not (Test-Path $InputFile)) {
    throw "Lifecycle event file not found: $InputFile"
}

$events = Import-Csv $InputFile

Write-Host ""
Write-Host "BATCH LIFECYCLE PROCESSING"
Write-Host "=========================="
Write-Host "Events found:" $events.Count
Write-Host ""

$results = @()

foreach ($event in $events) {

    $eventType = $event.EventType.Trim()
    $employeeID = $event.EmployeeID.Trim()

    Write-Host "Processing $eventType for $employeeID..."

    try {

        if ($eventType -eq "Mover") {

            if ([string]::IsNullOrWhiteSpace($event.NewJobTitle)) {
                throw "Mover event requires NewJobTitle."
            }

            & "./scripts/invoke-lifecycle.ps1" `
                -EventType $eventType `
                -EmployeeID $employeeID `
                -NewJobTitle $event.NewJobTitle
        }
        else {

            & "./scripts/invoke-lifecycle.ps1" `
                -EventType $eventType `
                -EmployeeID $employeeID
        }

        $results += [PSCustomObject]@{
            Timestamp   = (Get-Date).ToString("o")
            EventType   = $eventType
            EmployeeID  = $employeeID
            NewJobTitle = $event.NewJobTitle
            Result      = "SUCCESS"
            Error       = ""
        }
    }
    catch {

        Write-Host "FAILED:" $_.Exception.Message

        $results += [PSCustomObject]@{
            Timestamp   = (Get-Date).ToString("o")
            EventType   = $eventType
            EmployeeID  = $employeeID
            NewJobTitle = $event.NewJobTitle
            Result      = "FAILED"
            Error       = $_.Exception.Message
        }
    }

    Write-Host ""
}

$reportPath = "./reports/lifecycle-batch-results.csv"

$results |
    Export-Csv `
        -Path $reportPath `
        -NoTypeInformation

Write-Host ""
Write-Host "BATCH SUMMARY"
Write-Host "============="

$results |
    Group-Object Result |
    Select-Object Name, Count |
    Format-Table

Write-Host "Report:"
Write-Host $reportPath