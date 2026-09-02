Import-Module "./modules/RBAC.psm1" -Force

$employees = Import-Csv "./data/employees.csv"

$roleMapping = Get-Content "./config/role-mapping.json" |
    ConvertFrom-Json

$rbac = Get-Content "./config/rbac.json" |
    ConvertFrom-Json

foreach ($employee in $employees | Select-Object -First 10) {

     $result = Get-RequiredAccess `
            -Employee $employee `
            -RoleMapping $roleMapping `
            -RbacConfig $rbac
    
        Write-Host ""
        Write-Host "--------------------------------"
        Write-Host "Employee:" $result.Email
        Write-Host "Job Title:" $result.JobTitle
        Write-Host "Role Family:" $result.RoleFamily
        Write-Host "Status:" $result.Status
    
        Write-Host "Access Groups:"
    
        foreach ($group in $result.Groups) {
            Write-Host "- $group"
        }
    }