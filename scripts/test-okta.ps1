Import-Module "./modules/Okta.psm1" -Force

Write-Host ""
Write-Host "Testing Okta API connection..."
Write-Host ""

try {

    $users = Get-OktaUsers

    Write-Host "Connection successful."
    Write-Host "Users returned:" $users.Count

    Write-Host ""
    Write-Host "OKTA USERS"
    Write-Host "----------"

    $users |
        Select-Object `
            id,
            status,
            @{Name="Email"; Expression={$_.profile.email}},
            @{Name="FirstName"; Expression={$_.profile.firstName}},
            @{Name="LastName"; Expression={$_.profile.lastName}} |
        Format-Table

}
catch {

    Write-Host "Connection failed."
    Write-Host $_.Exception.Message

}