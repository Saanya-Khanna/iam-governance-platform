Import-Module "./modules/RBAC.psm1" -Force

$employees = Import-Csv "./data/employees.csv"
$roleMapping = Get-Content "./config/role-mapping.json" | ConvertFrom-Json
$rbac = Get-Content "./config/rbac.json" | ConvertFrom-Json

$results = foreach ($employee in $employees) {

    Get-RequiredAccess `
        -Employee $employee `
        -RoleMapping $roleMapping `
        -RbacConfig $rbac
}

Write-Host ""
Write-Host "Total employees:" $results.Count
Write-Host "Successful:" ($results | Where-Object Status -eq "SUCCESS").Count
Write-Host "Unmapped roles:" ($results | Where-Object Status -eq "UNMAPPED_ROLE").Count
Write-Host "Missing RBAC:" ($results | Where-Object Status -eq "NO_RBAC_MAPPING").Count