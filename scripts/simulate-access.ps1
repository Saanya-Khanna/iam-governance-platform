Import-Module "./modules/SoD.psm1" -Force

$sodConfig = Get-Content "./config/sod-rules.json" |
    ConvertFrom-Json

Import-Module "./modules/RBAC.psm1" -Force
Import-Module "./modules/Policy.psm1" -Force
Import-Module "./modules/Logging.psm1" -Force

$employees = Import-Csv "./data/employees.csv"

$roleMapping = Get-Content "./config/role-mapping.json" |
    ConvertFrom-Json

$rbac = Get-Content "./config/rbac.json" |
    ConvertFrom-Json

$policies = Get-Content "./config/policies.json" |
    ConvertFrom-Json

$results = foreach ($employee in $employees) {

    # STEP 1 — Determine required access
    $access = Get-RequiredAccess `
        -Employee $employee `
        -RoleMapping $roleMapping `
        -RbacConfig $rbac

    # If role mapping fails, record it and continue
    if ($access.Status -ne "SUCCESS") {

        Write-AuditLog `
            -Email $access.Email `
            -Action "ACCESS_EVALUATION" `
            -Target "N/A" `
            -Result $access.Status `
            -Reason "Unable to determine RBAC access"

        [PSCustomObject]@{
            Email           = $access.Email
            JobTitle        = $access.JobTitle
            RoleFamily      = $access.RoleFamily
            RequestedGroups = ""
            ApprovedGroups  = ""
            DeniedGroups    = ""
            Status          = $access.Status
        }

        continue
    }

    # STEP 2 — Evaluate access against policy
    $policyResult = Test-AccessPolicy `
        -Groups $access.Groups `
        -PolicyConfig $policies

    # STEP 3 — Check approved access for SoD conflicts
    
    $sodViolations = Test-SoDConflict `
        -Groups $policyResult.ApprovedGroups `
        -SoDConfig $sodConfig

    foreach ($violation in $sodViolations) {

    Write-AuditLog `
        -Email $access.Email `
        -Action "SOD_VIOLATION" `
        -Target "$($violation.GroupA) + $($violation.GroupB)" `
        -Result "FLAGGED" `
        -Reason $violation.Reason
        
    }

    # STEP 4 — Log denied groups
    foreach ($denied in $policyResult.DeniedGroups) {

        Write-AuditLog `
            -Email $access.Email `
            -Action "ACCESS_EVALUATION" `
            -Target $denied.Group `
            -Result "DENIED" `
            -Reason $denied.Reason
    }

    # STEP 5 — Build report record
    [PSCustomObject]@{
        Email           = $access.Email
        JobTitle        = $access.JobTitle
        RoleFamily      = $access.RoleFamily
        RequestedGroups = ($access.Groups -join ";")
        ApprovedGroups  = ($policyResult.ApprovedGroups -join ";")
        DeniedGroups    = (($policyResult.DeniedGroups |
                            ForEach-Object { $_.Group }) -join ";")
    
        SoDViolations   = (($sodViolations |
                            ForEach-Object {
                                "$($_.GroupA) + $($_.GroupB)"
                            }) -join ";")
    
        Status          = if ($sodViolations.Count -gt 0) {
                              "SOD_REVIEW_REQUIRED"
                          }
                          else {
                              "SUCCESS"
                          }
    }
}

$results |
    Export-Csv "./reports/access-review.csv" `
    -NoTypeInformation

Write-Host ""
Write-Host "Simulation complete."
Write-Host "Employees processed:" $results.Count
Write-Host "Report: ./reports/access-review.csv"

Write-Host "Audit log: ./logs/audit.csv"