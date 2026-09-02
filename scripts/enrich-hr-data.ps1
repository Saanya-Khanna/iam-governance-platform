$employees = Import-Csv "./data/employees.csv"

$department = @(
    "Administration",
    "Content / Media",
    "Design / Creative",
    "Education",
    "Engineering / IT",
    "Finance / Accounting",
    "HR / People",
    "Healthcare",
    "Legal / Compliance",
    "Operations",
    "Procurement / Supply Chain",
    "Public / Community Services",
    "Sales / Marketing",
    "Science / Research"
)

$locations = @(
    "New York",
    "Dallas",
    "Chicago",
    "Los Angeles",
    "Remote"
)

$workerTypes = @(
    "Employee",
    "Employee",
    "Employee",
    "Employee",
    "Contractor"
)

$roleMapping = Get-Content "./config/role-mapping.json" |
    ConvertFrom-Json

$counter = 100001

$enrichedEmployees = foreach ($employee in $employees) {

    $roleFamily = $roleMapping.($employee.'Job Title')

    # For this simulation, RoleFamily acts as Department.
    # This can be separated into independent department mappings later.

    $department = if ($roleFamily -eq "Other / Specialized") {
        "Operations"
    }
    else {
        $roleFamily
    }

    [PSCustomObject]@{
        EmployeeID       = "EMP$counter"
        FirstName        = $employee.'First Name'
        LastName         = $employee.'Last Name'
        Email            = $employee.Email
        JobTitle         = $employee.'Job Title'
        Department       = $department
        RoleFamily       = $roleFamily
        Location         = Get-Random -InputObject $locations
        WorkerType       = Get-Random -InputObject $workerTypes
        EmploymentStatus = "Active"
        HireDate         = (Get-Date).AddDays(-(Get-Random -Minimum 30 -Maximum 2500)).ToString("yyyy-MM-dd")
        TerminationDate  = ""
    }

    $counter++
}

$enrichedEmployees |
    Export-Csv "./data/hr-employees.csv" -NoTypeInformation

Write-Host ""
Write-Host "HR dataset created."
Write-Host "Employees:" $enrichedEmployees.Count
Write-Host "Output: ./data/hr-employees.csv"