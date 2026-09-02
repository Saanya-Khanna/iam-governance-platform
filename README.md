# IAM Governance & Workforce Access Automation Platform

An end-to-end Identity and Access Management (IAM) simulation that automates workforce identity lifecycle management, role-based access control, access governance, Okta provisioning, access certification, and remediation.

The project models how an enterprise IAM environment can use HR data as the authoritative identity source and translate workforce attributes into governed access decisions.

## Overview

The platform processes a synthetic workforce dataset of 10,000 employees and uses PowerShell as the IAM automation and policy engine.

It supports:

* Joiner, Mover, and Leaver (JML) lifecycle automation
* Role-Based Access Control (RBAC)
* Policy-based entitlement restrictions
* Separation of Duties (SoD) controls
* Okta user and group provisioning through REST APIs
* Access certification and reconciliation
* Excess-access detection and remediation
* Missing-access detection and remediation
* Orphan-account detection
* Approved identity exceptions
* Audit logging
* Batch lifecycle event processing
* Automated platform validation

## Architecture

```text
                    ┌─────────────────────┐
                    │  Synthetic HR Data  │
                    │  10,000 Employees   │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ Identity Lifecycle  │
                    │   J / M / L Engine  │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ Job Title → Role    │
                    │   Family Mapping    │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │        RBAC         │
                    │ Entitlement Bundles │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │ Governance Controls │
                    │ Policy + SoD Rules  │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │    Okta REST API    │
                    │ Users / Groups /    │
                    │ Lifecycle Actions   │
                    └──────────┬──────────┘
                               │
                 ┌─────────────┴─────────────┐
                 ▼                           ▼
        ┌─────────────────┐        ┌──────────────────┐
        │   Audit Logs    │        │ Access Review &  │
        │                 │        │  Certification   │
        └─────────────────┘        └────────┬─────────┘
                                           │
                                  ┌────────▼─────────┐
                                  │ Drift Detection │
                                  │ & Remediation   │
                                  └──────────────────┘
```

## Technology

* PowerShell 7
* Okta Integrator Free Plan
* Okta REST APIs
* JSON configuration
* CSV-based HR/event data
* Git / GitHub

## Workforce Data

The project uses a 10,000-record synthetic employee dataset as the simulated HR source of truth.

The IAM model uses attributes including:

* Employee ID
* Name
* Email
* Job Title
* Department
* Role Family
* Location
* Worker Type
* Employment Status
* Hire Date
* Termination Date

Additional workforce attributes were synthetically generated for IAM simulation.

Sensitive or irrelevant demographic attributes are not used to make access decisions.

## Role Model

The source dataset contains 639 unique job titles.

These titles are normalized into 15 role families:

* Administration
* Content / Media
* Design / Creative
* Education
* Engineering / IT
* Finance / Accounting
* HR / People
* Healthcare
* Legal / Compliance
* Operations
* Other / Specialized
* Procurement / Supply Chain
* Public / Community Services
* Sales / Marketing
* Science / Research

Each role family maps to an RBAC entitlement bundle.

For example:

```text
Procurement / Supply Chain
        │
        ├── corp-basic
        ├── vpn-access
        └── procurement-access
```

Broad job classifications do not automatically grant privileged administrative access.

## Joiner Workflow

For a new employee, the platform:

1. Reads the employee's HR attributes.
2. Maps the job title to a role family.
3. Determines required RBAC entitlements.
4. Applies policy restrictions.
5. Creates or resolves the Okta identity.
6. Assigns approved Okta groups.
7. Records the operation in the audit log.

```text
HR Record
   ↓
Role Mapping
   ↓
RBAC
   ↓
Policy Evaluation
   ↓
Okta User
   ↓
Group Assignment
   ↓
Audit
```

## Mover Workflow

When an employee changes roles, the system calculates the difference between old and new access.

For example:

```text
Old role: Content / Media
New role: Engineering / IT

REMOVE
content-access

ADD
vpn-access
engineering-access

KEEP
corp-basic
```

Only the required entitlement differences are reconciled.

## Leaver Workflow

For terminated identities, the platform:

1. Locates the Okta account.
2. Queries its actual group memberships.
3. Identifies IAM-managed entitlements.
4. Removes managed access.
5. Deactivates the Okta account.
6. Records the deprovisioning action.

The termination workflow queries actual IdP state rather than relying exclusively on HR-derived expected access.

## Policy Controls

RBAC eligibility does not automatically imply authorization.

Privileged groups such as:

```text
finance-admin
hr-admin
security-admin
user-admin
production-admin
```

are restricted from automatic assignment.

These entitlements represent access that would require a separate approval process in a production IAM environment.

## Separation of Duties

The platform evaluates conflicting entitlement combinations.

Example:

```text
accounts-payable-create
        +
payment-approve
        =
SoD Violation
```

Other simulated conflicts include:

* Payroll preparation vs. payroll approval
* Identity administration vs. access-review approval
* Production deployment vs. production change approval

SoD findings receive higher review priority than ordinary access drift.

## Access Certification

The governance engine compares:

```text
Expected Access
      vs.
Actual Okta Access
```

Expected access is calculated from HR attributes, role mapping, RBAC, and policy controls.

Actual access is retrieved directly from Okta.

Accounts can be classified as:

```text
COMPLIANT
MISSING_ACCESS
EXCESS_ACCESS
SOD_VIOLATION
ORPHAN_ACCOUNT
APPROVED_EXCEPTION
REVIEW_REQUIRED
```

## Access Drift

### Excess Access

If an identity has an IAM-managed entitlement that is not authorized by its current RBAC profile, the certification engine flags:

```text
EXCESS_ACCESS
```

The remediation workflow can remove the excess entitlement from Okta, log the action, and re-certify the identity.

### Missing Access

If an expected RBAC entitlement is absent from Okta, the engine flags:

```text
MISSING_ACCESS
```

Before restoration, the remediation workflow verifies that the missing group appears in the identity's expected RBAC entitlement set.

This prevents the remediation process from granting arbitrary access.

After remediation, the identity can be re-certified as:

```text
COMPLIANT
```

## Orphan Accounts and Exceptions

An identity existing in Okta but absent from the HR source is normally classified as:

```text
ORPHAN_ACCOUNT
```

However, not every non-HR identity is unauthorized.

The project therefore maintains an explicit identity exception registry for approved identities such as:

* Administrative accounts
* Test accounts

Approved identities remain visible in certification results but are classified as:

```text
APPROVED_EXCEPTION
```

This avoids silently excluding non-workforce identities from governance.

## Batch Lifecycle Processing

Lifecycle events can be processed from a CSV feed.

Example:

```csv
EventType,EmployeeID,NewJobTitle
Joiner,EMP100007,
Mover,EMP100007,Broadcast engineer
Leaver,EMP100007,
```

The batch processor executes each event independently and records success or failure without terminating the entire batch when one event fails.

## Audit Logging

Lifecycle and remediation operations generate audit records containing:

* Timestamp
* Identity
* Action
* Target
* Result
* Reason

Examples of auditable actions include:

```text
JOINER
MOVER
LEAVER
ACCESS_REMEDIATION
MISSING_ACCESS_REMEDIATION
SOD_VIOLATION
```

Generated logs are excluded from source control.

## Validation

The project includes a repeatable validation suite covering:

* HR dataset integrity
* RBAC resolution
* Entitlement generation
* Policy restrictions
* SoD detection
* Compliant-access classification
* Missing-access detection
* Excess-access detection
* SoD review prioritization

Current validation:

```text
Passed: 10
Failed: 0

ALL PLATFORM VALIDATIONS PASSED
```

The validation suite does not modify Okta and can therefore be run repeatedly.

## Project Structure

```text
iam-governance-platform/
│
├── config/
│   ├── identity-exceptions.json
│   ├── policies.json
│   ├── rbac.json
│   ├── role-mapping.json
│   └── sod-rules.json
│
├── data/
│   ├── employees.csv
│   ├── hr-employees.csv
│   └── lifecycle-events.csv
│
├── logs/
│   └── audit.csv
│
├── modules/
│   ├── AccessReview.psm1
│   ├── JML.psm1
│   ├── Logging.psm1
│   ├── Okta.psm1
│   ├── Policy.psm1
│   ├── RBAC.psm1
│   └── SoD.psm1
│
├── reports/
│   ├── access-certification.csv
│   ├── access-review.csv
│   └── lifecycle-batch-results.csv
│
├── scripts/
│   ├── enrich-hr-data.ps1
│   ├── invoke-lifecycle.ps1
│   ├── process-lifecycle-events.ps1
│   ├── remediate-access-review.ps1
│   ├── remediate-missing-access.ps1
│   ├── run-okta-access-review.ps1
│   ├── simulate-access.ps1
│   ├── sync-okta-groups.ps1
│   └── validate-platform.ps1
│
└── README.md
```

## Security Design

Several security controls are intentionally built into the project:

**Secrets management**

Okta API credentials are read from environment variables rather than hard-coded into scripts.

```powershell
$env:OKTA_DOMAIN
$env:OKTA_TOKEN
```

Secret configuration, logs, and generated reports should not be committed to Git.

**Least privilege**

Broad role families receive business access rather than administrative privileges.

Privileged entitlements are separated from automatic RBAC assignment.

**Defense in depth**

Missing-access remediation verifies that an entitlement is part of the identity's expected RBAC access before granting it.

**Actual-state verification**

Deprovisioning and certification query Okta directly rather than assuming the IdP matches HR-derived state.

Group-removal operations verify that the membership was actually removed instead of treating an accepted API request as sufficient evidence.

**Auditability**

Lifecycle and remediation operations generate structured audit records.

## Running the Project

Set the Okta environment variables for the current PowerShell session:

```powershell
$env:OKTA_DOMAIN = "https://your-tenant.okta.com"
$env:OKTA_TOKEN = "YOUR_TOKEN"
```

Do not store the API token in the repository.

Run platform validation:

```powershell
. ./scripts/validate-platform.ps1
```

Run a lifecycle event:

```powershell
. ./scripts/invoke-lifecycle.ps1 `
    -EventType Joiner `
    -EmployeeID "EMP100004"
```

Process a lifecycle feed:

```powershell
. ./scripts/process-lifecycle-events.ps1
```

Run access certification:

```powershell
. ./scripts/run-okta-access-review.ps1
```

## Design Scope

This project is an IAM engineering and governance simulation rather than a production identity platform.

The HR attributes, role model, entitlement catalog, and SoD rules are synthetic and intended to demonstrate IAM architecture and automation concepts.

A production implementation would additionally require controls such as:

* Formal approval workflows
* Production HRIS integration
* Scoped OAuth service applications
* Secrets management
* Manager/application-owner certification
* API pagination and rate-limit handling
* Retry and rollback strategies
* Centralized monitoring
* Change management
* Formal role engineering and entitlement ownership

## Key Takeaways

This project demonstrates the relationship between identity administration and identity governance rather than treating provisioning as the entire IAM problem.

It implements:

```text
HR Source of Truth
        ↓
Identity Lifecycle
        ↓
Role Engineering
        ↓
RBAC
        ↓
Policy / SoD
        ↓
Okta Provisioning
        ↓
Access Certification
        ↓
Drift Detection
        ↓
Controlled Remediation
        ↓
Audit Evidence
```

The result is a working simulation of a governed workforce identity lifecycle with real IdP integration.

