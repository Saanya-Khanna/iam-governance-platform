function Get-OktaHeaders {

    if (-not $env:OKTA_DOMAIN) {
        throw "OKTA_DOMAIN environment variable is not set."
    }

    if (-not $env:OKTA_TOKEN) {
        throw "OKTA_TOKEN environment variable is not set."
    }

    return @{
        Authorization  = "SSWS $env:OKTA_TOKEN"
        Accept         = "application/json"
        "Content-Type" = "application/json"
    }
}


function Get-OktaUsers {

    $headers = Get-OktaHeaders
    $uri = "$env:OKTA_DOMAIN/api/v1/users"

    try {
        return Invoke-RestMethod `
            -Uri $uri `
            -Method GET `
            -Headers $headers `
            -ErrorAction Stop
    }
    catch {
        throw "Unable to retrieve Okta users: $($_.Exception.Message)"
    }
}


function Get-OktaGroups {

    $headers = Get-OktaHeaders
    $uri = "$env:OKTA_DOMAIN/api/v1/groups"

    try {
        return Invoke-RestMethod `
            -Uri $uri `
            -Method GET `
            -Headers $headers `
            -ErrorAction Stop
    }
    catch {
        throw "Unable to retrieve Okta groups: $($_.Exception.Message)"
    }
}


function Get-OktaUserByEmail {
    param (
        [Parameter(Mandatory)]
        [string]$Email
    )

    $headers = Get-OktaHeaders

    $encodedLogin = [System.Uri]::EscapeDataString($Email)

    $uri = "$($env:OKTA_DOMAIN)/api/v1/users/$encodedLogin"

    try {
        return Invoke-RestMethod `
            -Uri $uri `
            -Method GET `
            -Headers $headers `
            -ErrorAction Stop
    }
    catch {

        if ($_.Exception.Response.StatusCode.value__ -eq 404) {
            return $null
        }

        throw "Unable to retrieve Okta user '$Email': $($_.Exception.Message)"
    }
}


function Get-OktaGroupByName {
    param (
        [Parameter(Mandatory)]
        [string]$GroupName
    )

    $headers = Get-OktaHeaders

    $searchExpression = "profile.name eq `"$GroupName`""
    $encodedSearch = [System.Uri]::EscapeDataString($searchExpression)

    $uri = "$env:OKTA_DOMAIN/api/v1/groups?search=$encodedSearch"

    try {

        $groups = Invoke-RestMethod `
            -Uri $uri `
            -Method GET `
            -Headers $headers `
            -ErrorAction Stop

        return $groups |
            Where-Object {
                $_.profile.name -eq $GroupName
            } |
            Select-Object -First 1
    }
    catch {
        throw "Unable to find Okta group '$GroupName': $($_.Exception.Message)"
    }
}


function Get-OktaUserGroups {
    param (
        [Parameter(Mandatory)]
        [string]$UserId
    )

    $headers = Get-OktaHeaders
    $uri = "$env:OKTA_DOMAIN/api/v1/users/$UserId/groups"

    try {
        return Invoke-RestMethod `
            -Uri $uri `
            -Method GET `
            -Headers $headers `
            -ErrorAction Stop
    }
    catch {
        throw "Unable to retrieve groups for Okta user '$UserId': $($_.Exception.Message)"
    }
}


function New-OktaGroup {
    param (
        [Parameter(Mandatory)]
        [string]$GroupName,

        [string]$Description = "Managed by IAM Governance Platform"
    )

    $existingGroup = Get-OktaGroupByName `
        -GroupName $GroupName

    if ($existingGroup) {

        Write-Host "Group already exists: $GroupName"

        return $existingGroup
    }

    $headers = Get-OktaHeaders
    $uri = "$env:OKTA_DOMAIN/api/v1/groups"

    $body = @{
        profile = @{
            name        = $GroupName
            description = $Description
        }
    } | ConvertTo-Json -Depth 5

    try {

        $group = Invoke-RestMethod `
            -Uri $uri `
            -Method POST `
            -Headers $headers `
            -Body $body `
            -ErrorAction Stop

        if (-not $group.id) {
            throw "Okta returned no group ID."
        }

        Write-Host "Created group: $GroupName"
        Write-Host "Group ID:" $group.id

        return $group
    }
    catch {
        throw "Unable to create Okta group '$GroupName': $($_.Exception.Message)"
    }
}


function New-OktaUser {
    param (
        [Parameter(Mandatory)]
        [string]$FirstName,

        [Parameter(Mandatory)]
        [string]$LastName,

        [Parameter(Mandatory)]
        [string]$Email
    )

    $existingUser = Get-OktaUserByEmail `
        -Email $Email

    if ($existingUser) {

        Write-Host "User already exists: $Email"

        return $existingUser
    }

    $headers = Get-OktaHeaders

    # Create the user without activating the account.
    # This prevents an activation email from being sent
    # while we are testing the IAM workflow.
    $uri = "$env:OKTA_DOMAIN/api/v1/users?activate=false"

    $body = @{
        profile = @{
            firstName = $FirstName
            lastName  = $LastName
            email     = $Email
            login     = $Email
        }
    } | ConvertTo-Json -Depth 5

    try {

        $user = Invoke-RestMethod `
            -Uri $uri `
            -Method POST `
            -Headers $headers `
            -Body $body `
            -ErrorAction Stop

        if (-not $user.id) {
            throw "Okta returned no user ID."
        }

        Write-Host "Created Okta user: $Email"
        Write-Host "Created user ID:" $user.id
        Write-Host "Created user status:" $user.status

        return $user
    }
    catch {
        throw "Unable to create Okta user '$Email': $($_.Exception.Message)"
    }
}


function Add-OktaUserToGroup {
    param (
        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$GroupName
    )

    $group = Get-OktaGroupByName `
        -GroupName $GroupName

    if (-not $group) {
        throw "Okta group not found: $GroupName"
    }

    $headers = Get-OktaHeaders

    $uri = "$env:OKTA_DOMAIN/api/v1/groups/$($group.id)/users/$UserId"

    try {

        Invoke-RestMethod `
            -Uri $uri `
            -Method PUT `
            -Headers $headers `
            -ErrorAction Stop

        Write-Host "Assigned group: $GroupName"
    }
    catch {
        throw "Unable to assign '$GroupName' to Okta user '$UserId': $($_.Exception.Message)"
    }
}

function Remove-OktaUserFromGroup {
    param (
        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$GroupName
    )

    $group = Get-OktaGroupByName -GroupName $GroupName

    if (-not $group) {
        throw "Okta group not found: $GroupName"
    }

    if ($group.type -ne "OKTA_GROUP") {
        throw "Group '$GroupName' is not an OKTA_GROUP and cannot be directly managed."
    }

    $headers = Get-OktaHeaders

    $uri = "$env:OKTA_DOMAIN/api/v1/groups/$($group.id)/users/$UserId"

    Write-Host "Removing group membership:"
    Write-Host "User ID:" $UserId
    Write-Host "Group:" $GroupName
    Write-Host "Group ID:" $group.id

    try {

        Invoke-RestMethod `
            -Uri $uri `
            -Method DELETE `
            -Headers $headers `
            -ErrorAction Stop

        Start-Sleep -Seconds 1

        # Verify against live Okta state
        $remainingGroups = Get-OktaUserGroups -UserId $UserId

        $stillAssigned = $remainingGroups |
            Where-Object {
                $_.id -eq $group.id
            }

        if ($stillAssigned) {
            throw "Okta accepted the DELETE request, but '$GroupName' is still assigned to the user."
        }

        Write-Host "Verified removal: $GroupName"
    }
    catch {
        throw "Unable to remove '$GroupName' from Okta user '$UserId': $($_.Exception.Message)"
    }
}

function Disable-OktaUser {
    param (
        [Parameter(Mandatory)]
        [string]$UserId
    )

    $headers = Get-OktaHeaders
    $uri = "$env:OKTA_DOMAIN/api/v1/users/$UserId/lifecycle/deactivate"

    try {
        Invoke-RestMethod `
            -Uri $uri `
            -Method POST `
            -Headers $headers `
            -ErrorAction Stop

        Write-Host "Deactivated Okta user: $UserId"
    }
    catch {
        throw "Unable to deactivate Okta user '$UserId': $($_.Exception.Message)"
    }
}


Export-ModuleMember -Function `
    Get-OktaUsers,
    Get-OktaGroups,
    Get-OktaUserByEmail,
    Get-OktaGroupByName,
    Get-OktaUserGroups,
    New-OktaGroup,
    New-OktaUser,
    Add-OktaUserToGroup,
    Remove-OktaUserFromGroup,
    Disable-OktaUser