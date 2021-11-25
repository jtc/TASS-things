#Requires -Version 7

Import-Module $PSScriptRoot\TASS

# TASS API details
# https://hub.tassweb.com.au/confluence/help-centre/documentation/tass-web/system-admin/utilities/api-gateway-maintenance/tass-apis/tass-api-applications
# https://github.com/TheAlphaSchoolSystemPTYLTD/api-introduction
# https://github.com/TheAlphaSchoolSystemPTYLTD/student-details
$TassEndpoint    = 'https://tass.example.edu/tassweb/api/'
$TassMethod      = 'getStudentsDetails'
$TassAppCode     = 'EXAMPLE'
$TassCompanyCode = '01'
$TassApiVersion  = '3' # v2 should work as well
$TassTokenKey    = 'ev27dSDGQAhq3m7zdRb6Tw=='

# TODO IMPORTANT - replace dates for other years
$NaplanStartDate = Get-Date 2021-05-11
$NaplanEndDate = Get-Date 2021-05-21
$NaplanYears = @(5,7,9)

$FileExtension = '.pdf'

function Rename-NaplanFiles ($currentstatus) {
    $tassStudents = (Submit-TASSApiRequest -Endpoint $TassEndpoint -Method $TassMethod -AppCode $TassAppCode -CompanyCode $TassCompanyCode -ApiVersion $TassApiVersion -Parameters (@{currentstatus=$currentstatus} | ConvertTo-Json -Compress) -TokenKey $TassTokenKey).students | Where-Object {(Get-Date $_.general_details.date_of_entry) -lt $NaplanStartDate -and (!$_general_details.date_of_leaving -or (Get-Date $_.general_details.date_of_leaving) -gt $NaplanEndDate)}

    ForEach ($student In $tassStudents) {
        $adjustedYear = $student.school_details.year_group + ((Get-Date $NaplanEndDate -Format "yyyy")/1) - (($student.general_details.date_of_leaving ? (Get-Date $student.general_details.date_of_leaving -Format "yyyy") : (Get-Date -Format "yyyy"))/1)
        If ($NaplanYears -contains $adjustedYear) {
            Rename-Item `
                    -Path "$adjustedYear\\$((@($student.general_details.first_name, $student.general_details.other_name, $student.general_details.surname).Where({$_}) -Join '_') -Replace '[^a-zA-Z\d]', '_')$FileExtension" `
                    -NewName "$($student.general_details.student_code)$FileExtension"
        }
    }
}


Rename-NaplanFiles 'current'
Rename-NaplanFiles 'noncurrent'
