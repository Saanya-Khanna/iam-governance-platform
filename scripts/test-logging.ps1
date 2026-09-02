Import-Module "./modules/Logging.psm1" -Force

Write-AuditLog `
    -Email "tsharp@example.net" `
    -Action "ACCESS_EVALUATION" `
    -Target "content-access" `
    -Result "APPROVED" `
    -Reason "RBAC Role Family: Content / Media"

Write-Host "Audit log entry created."