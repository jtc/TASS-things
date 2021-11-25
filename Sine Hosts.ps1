#Requires -Version 6.1

Import-Module $PSScriptRoot\TASS

# TASS API Details for Employee/HR API
# https://hub.tassweb.com.au/confluence/help-centre/documentation/tass-web/system-admin/utilities/api-gateway-maintenance/tass-apis/tass-api-applications
# https://github.com/TheAlphaSchoolSystemPTYLTD/api-introduction
# https://github.com/TheAlphaSchoolSystemPTYLTD/employee-hr
$companyCode = '01'
$appCode     = 'SINE'
$tokenKey    = 'ev27dSDGQAhq3m7zdRb6Tw=='
$endpoint    = 'https://tass.example.edu/tassweb/api/'
$parameters  = "{""date"":""$(Get-Date -Format "dd/MM/yyyy")""}"

# TASS HR UD field which stores if employee's mobile should be sent to Sine. Note this script
# currently only works with Australian mobile / pre-formatted international numbers, but could be modified.
$udArea = '1'
$udId = '4'

# Sine API Details
# https://sine.support/en/articles/2103855-active-directory-ldap-integration
$sineApiKey = 'Tv4wMtHc7FF4YCCn'
$removeHosts = $true
$sendEmails = $false

# Sine values
$defaultGroup = 'Staff'
$defaultSite = 'The Alpha Progressive School'


$tempCsv = [System.IO.Path]::GetTempFileName()
if ($tempCsv -eq $null) {
    Write-Error "Could not get a tempfile"
    Exit
}

$sineHosts = @()

Write-Host "Getting data from TASS..."
$tassResponse = Submit-TASSApiRequest -Endpoint $endpoint -Method 'getEmployeesDetails' -AppCode $appCode -CompanyCode $companyCode -ApiVersion '2' -Parameters $parameters -TokenKey $tokenKey

Write-Host "Processing data..."
ForEach($employee In $tassResponse.employees) {
    If($employee.general.school_email) {
        Write-Host "Getting TASS UD information for $($employee.general.employee_code)..."
        $tassUd = Submit-TASSApiRequest -Endpoint $endpoint -Method 'getEmployeeUD' -AppCode $appCode -CompanyCode $companyCode -ApiVersion '2' -Parameters "{""code"":""$($employee.general.employee_code)"",""area"":""$udArea""}" -TokenKey $tokenKey
        
        $sineHosts += [PSCustomObject]@{
            Email = $employee.general.school_email
            'First Name' = $employee.general.preferred_name
            'Last Name' = $employee.general.surname
            'Group Name' = $defaultGroup
            'Site Name' = $defaultSite
            Mobile =
                If($tassUd.areas[0].ud.$udId.value -eq 'Y') {
                    # Get one mobile only and remove non-numbers / +s
                    $mobile = ([string]$employee.address.mobile_phone).Split(";", [System.StringSplitOptions]::RemoveEmptyEntries)[0] -replace '[^+0-9]'
                    
                    # Format Australian mobiles to E.164
                    If($mobile.StartsWith('04') -and ($mobile.Length -eq 10)) {
                        $mobile -replace '^0', '61'
                    } ElseIf($mobile.StartsWith('+')) {
                        $mobile -replace '+'
                    }
                }
        }
    }
}

$sineHosts | Export-Csv $tempCsv -NoTypeInformation

Write-Host "Uploading data to Sine..."
try {
    Invoke-RestMethod -Uri "https://api.sine.co/v1/host/csv-upload/api-key?remove-hosts=$($removeHosts.ToString().ToLower())&send-emails=$($sendEmails.ToString().ToLower())" -Method Post -Headers @{ 'X-Sine-Api-Key' = $sineApiKey } -Form @{ file = Get-Item $tempCsv }
    Write-Host "Done!"
} catch [Exception] {
    Write-Host "Error connecting to $uri"
    Write-Host $_.Exception.Message
} finally {
    Remove-Item $tempCsv
}