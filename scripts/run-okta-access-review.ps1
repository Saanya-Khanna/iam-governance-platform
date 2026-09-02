$exceptions = Get-Content "./config/identity-exceptions.json" |
    ConvertFrom-Json

Import-Module "./modules/RBAC.psm1" -Force
Import-Module "./modules/Policy.psm1" -Force
Import-Module "./modules/SoD.psm1" -Force
Import-Module "./modules/AccessReview.psm1" -Force
Import-Module "./modules/Okta.psm1" -Force


# -----------------------------
# Load data and configuration
# -----------------------------

$employees = Import-Csv "./data/hr-employees.csv"

$roleMapping = Get-Content "./config/role-mapping.json" |
    ConvertFrom-Json

$rbac = Get-Content "./config/rbac.json" |
    ConvertFrom-Json

$policies = Get-Content "./config/policies.json" |
    ConvertFrom-Json

$sod = Get-Content "./config/sod-rules.json" |
    ConvertFrom-Json


Write-Host ""
Write-Host "OKTA ACCESS CERTIFICATION"
Write-Host "========================="
Write-Host ""


# -----------------------------
# Build HR lookup by email
# -----------------------------

$employeeLookup = @{}

foreach ($employee in $employees) {
    $employeeLookup[$employee.Email.ToLower()] = $employee
}


# -----------------------------
# Determine groups managed by us
# -----------------------------

$managedGroups = @()

foreach ($role in $rbac.PSObject.Properties) {
    $managedGroups += @($role.Value.groups)
}

$managedGroups = @(
    $managedGroups |
        Sort-Object -Unique
)


# -----------------------------
# Retrieve Okta users
# -----------------------------

$oktaUsers = Get-OktaUsers

Write-Host "Okta users found:" $oktaUsers.Count
Write-Host ""


$results = @()


# -----------------------------
# Review each Okta identity
# -----------------------------

foreach ($oktaUser in $oktaUsers) {

    $email = $oktaUser.profile.email

    if (-not $email) {
        continue
    }


    Write-Host "Reviewing:" $email


    $emailKey = $email.ToLower()


    # -------------------------
    # Orphan account detection
    # -------------------------

    # -------------------------
# Non-HR identity detection
# -------------------------

if (-not $employeeLookup.ContainsKey($emailKey)) {

    $actualOktaGroups = Get-OktaUserGroups `
        -UserId $oktaUser.id

    $actualGroupNames = @(
        $actualOktaGroups |
            ForEach-Object {
                $_.profile.name
            }
    )

    $actualManagedGroups = @(
        $actualGroupNames |
            Where-Object {
                $_ -in $managedGroups
            }
    )

    # Check approved exception registry

    $exception = $exceptions.exceptions |
        Where-Object {
            $_.email -eq $email
        } |
        Select-Object -First 1

    if ($exception -and $exception.approved -eq $true) {

        $results += [PSCustomObject]@{
            EmployeeID     = ""
            Email          = $email
            OktaStatus     = $oktaUser.status
            RoleFamily     = ""
            ExpectedGroups = ""
            ActualGroups   = ($actualManagedGroups -join ";")
            MissingAccess  = ""
            ExcessAccess   = ""
            SoDViolations  = ""
            IdentityType   = $exception.identityType
            ExceptionReason = $exception.reason
            Status         = "APPROVED_EXCEPTION"
        }
    }
    else {

        $results += [PSCustomObject]@{
            EmployeeID     = ""
            Email          = $email
            OktaStatus     = $oktaUser.status
            RoleFamily     = ""
            ExpectedGroups = ""
            ActualGroups   = ($actualManagedGroups -join ";")
            MissingAccess  = ""
            ExcessAccess   = ($actualManagedGroups -join ";")
            SoDViolations  = ""
            IdentityType   = "UNKNOWN"
            ExceptionReason = ""
            Status         = "ORPHAN_ACCOUNT"
        }
    }

    continue
}

    # -------------------------
    # Employee exists in HR
    # -------------------------

    $employee = $employeeLookup[$emailKey]


    $actualOktaGroups = Get-OktaUserGroups `
        -UserId $oktaUser.id


    # Only compare groups controlled by our IAM engine.
    # This prevents Okta system groups such as Everyone
    # from being incorrectly classified as excess access.

    $actualManagedGroups = @(
        $actualOktaGroups |
            ForEach-Object {
                $_.profile.name
            } |
            Where-Object {
                $_ -in $managedGroups
            }
    )


    $review = Test-UserAccess `
        -Employee $employee `
        -ActualGroups $actualManagedGroups `
        -RoleMapping $roleMapping `
        -RbacConfig $rbac `
        -PolicyConfig $policies `
        -SoDConfig $sod


    $results += [PSCustomObject]@{
        EmployeeID     = $review.EmployeeID
        Email          = $review.Email
        OktaStatus     = $oktaUser.status
        RoleFamily     = $review.RoleFamily
        ExpectedGroups = $review.ExpectedGroups
        ActualGroups   = $review.ActualGroups
        MissingAccess  = $review.MissingAccess
        ExcessAccess   = $review.ExcessAccess
        SoDViolations  = $review.SoDViolations
        IdentityType    = "WORKFORCE"
        ExceptionReason = ""
        Status         = $review.Status
    }
}


# -----------------------------
# Export certification report
# -----------------------------

$reportPath = "./reports/access-certification.csv"

$results |
    Export-Csv `
        -Path $reportPath `
        -NoTypeInformation


# -----------------------------
# Summary
# -----------------------------

Write-Host ""
Write-Host "ACCESS REVIEW SUMMARY"
Write-Host "====================="

Write-Host "Accounts reviewed:" $results.Count

$summary = $results |
    Group-Object Status |
    Sort-Object Name

$summary |
    Select-Object `
        @{Name="Status"; Expression={$_.Name}},
        Count |
    Format-Table


Write-Host ""
Write-Host "Report generated:"
Write-Host $reportPath