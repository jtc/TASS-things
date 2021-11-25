#Requires -Version 6.1

Import-Module $PSScriptRoot\TASS

# TASS API details
# https://hub.tassweb.com.au/confluence/help-centre/documentation/tass-web/system-admin/utilities/api-gateway-maintenance/tass-apis/tass-api-applications
# https://github.com/TheAlphaSchoolSystemPTYLTD/api-introduction
# https://github.com/TheAlphaSchoolSystemPTYLTD/library-integration
$TassEndpoint    = 'https://tass.example.edu/tassweb/api/'
$TassAppCode     = 'INFINITI'
$TassCompanyCode = '01'
$TassApiVersion  = '3'
$TassTokenKey    = 'ev27dSDGQAhq3m7zdRb6Tw=='
$TassCommType    = 'tkco'

# Concord Infiniti API Details
# https://support.concord.com.au/support/solutions/articles/1000292387-non-interactive-contacts-import-and-update
$ConcordDomain                = 'school.concordinfiniti.com'
$ConcordUsername              = 'autoimport'
$ConcordPassword              = 'gfS99UJuw2w8H^dQFn6a^yjkh@mqwYbmM5jF69FNEkbzGj&vQTQfdgg7u$t4kByx'
$ConcordContactsMode          = 'replaceDeclaredPatronsKeepCustomContacts'
$ConcordStudentEmailScenario  = 'ANY'
$ConcordStudentMobileScenario = 'NONE'
$ConcordParentEmailScenario   = 'OVERDUE;OVERDUE_ESCALATION_ONE;OVERDUE_ESCALATION_TWO;OVERDUE_ESCALATION_THREE'

$GraduationYearLevel = 12

# TODO: API field to use for Concord Infiniti username
# TODO: API field to use as student and parent addresse?
# TODO: Student communication scenarios? (Done?)
# TODO: More parent communication scenarios

# Function to convert a Y/N flag to a TRUE/FALSE bool
function Convert-FlagToBool ($Flag) {
    If ($Flag -eq 'Y') {
        return $true
    } else {
        return $false
    }
}

function SemicolonSplit ($String) {
    return ([string]$String).Split(";", [System.StringSplitOptions]::RemoveEmptyEntries)
}

# Function to add a Concord Infiniti contact to the ContactsList
function Add-ConcordContact ($ContactsList, $Username, $Type, $Role, $Primary, $Addressee, $Contact, $Sms, $Scenarios) {
    $ContactsList.Add([PSCustomObject]@{
        username = $Username
        type = $Type
        role = $Role
        primary = $Primary
        addressee = $Addressee
        contact = $Contact
        sms = $Sms
        scenarios = $Scenarios
    })
}

function StudentContacts ($TassCurrentStudents, $ContactsList) {
    ForEach($student In $TassCurrentStudents) {
        $primaryContact = $true
        ForEach($email In SemicolonSplit $student.emailAddress) {
            Add-ConcordContact -contactsList $ContactsList -Username $student.username -Type 'email' -Role 'patron' -Primary $primaryContact -Addressee $student.preferredName -Contact $email.Trim() -Scenarios $ConcordStudentEmailScenario
            $primaryContact = $false
        }

        $primaryContact = $true
        ForEach($mobile In SemicolonSplit ([string]($student.mobilePhone).Trim())) { # TODO: Ask TASS not to return spaces in empty mobile phone
            Add-ConcordContact -contactsList $ContactsList -Username $student.username -Type 'phone' -Role 'patron' -Primary $primaryContact -Addressee $student.preferredName -Contact $mobile.Trim() -Sms $true -Scenarios $ConcordStudentMobileScenario
            # Can use ($mobile -replace '[^+0-9 ]') instead of $mobile if wishing to strip non-numbers/+s
            $primaryContact = $false
        }

        ForEach ($address In $student.addresses) {
            ForEach ($email In SemicolonSplit $address.email) {
                Add-ConcordContact -contactsList $ContactsList -Username $student.username -Type 'email' -Role 'guardian' -Primary $false -Addressee $address.salutation -Contact $email.Trim() -Scenarios $ConcordParentEmailScenario
            }

            ForEach ($email In SemicolonSplit $address.email2) {
                Add-ConcordContact -contactsList $ContactsList -Username $student.username -Type 'email' -Role 'guardian' -Primary $false -Addressee $address.salutation -Contact $email.Trim() -Scenarios $ConcordParentEmailScenario
            }

            ForEach ($phone In SemicolonSplit $address.homePhone) {
                Add-ConcordContact -contactsList $ContactsList -Username $student.username -Type 'phone' -Role 'guardian' -Primary $false -Addressee $address.salutation -Contact "(H) $($phone.Trim())" -Scenarios 'NONE'
            }

            ForEach ($phone In SemicolonSplit $address.businessPhone) {
                Add-ConcordContact -contactsList $ContactsList -Username $student.username -Type 'phone' -Role 'guardian' -Primary $false -Addressee $address.salutation -Contact "(B) $($phone.Trim())" -Scenarios 'NONE'
            }

            ForEach ($mobile In SemicolonSplit $address.mobile1) {
                Add-ConcordContact -contactsList $ContactsList -Username $student.username -Type 'phone' -Role 'guardian' -Primary $false -Addressee $address.salutation -Contact "(M1) $($mobile.Trim())" -Sms (Convert-FlagToBool -Flag $address.smsFlag1) -Scenarios 'NONE'
            }

            ForEach ($mobile In SemicolonSplit $address.mobile2) {
                Add-ConcordContact -contactsList $ContactsList -Username $student.username -Type 'phone' -Role 'guardian' -Primary $false -Addressee $address.salutation -Contact "(M2) $($mobile.Trim())"  -Sms (Convert-FlagToBool -Flag $address.smsFlag2) -Scenarios 'NONE'
            }
        }
    }
}

function StudentPatrons ($tassStudents, $patronsList) {
    ForEach ($student In $tassStudents) {
        if ($student.scholasticYear -in 7, 8, 9) {
            $concordFormClass = [string]$student.scholasticYear + [string]$student.rollClass
        } else {
            $concordFormClass = [string]$student.pcTutorGroup    
        }

        if ($student.gender -in 'M', 'F') {
            $concordGender = $student.gender
        } else {
            $concordGender = $null
        }

        # if () # WIP

        $patronsList.Add(@{
            username = $student.username
            enabled = $true
            staffmember = $false
            givenname = $student.first_name
            surname = $student.surname
            middlename = $student.other_name
            preferredname = $student.preferredName
            emailaddress = $student.emailAddress
            graduationyear = '' #TODO
            librarybarcode = $student.studCode
            adminsystemid = $student.studCode
            gender = $concordGender
            formclass = $concordFormClass 
        })
    }
}

$tempCsv = [System.IO.Path]::GetTempFileName()
if ($tempCsv -eq $null) {
    Write-Error "Could not get a tempfile"
    Exit
}

Write-Host "Getting student data from TASS..."
$TassCurrentStudents = (Submit-TASSApiRequest -Endpoint $TassEndpoint -Method 'getStudents' -AppCode $TassAppCode -CompanyCode $TassCompanyCode -ApiVersion $TassApiVersion -Parameters (@{currentstatus="current";commtype=$TassCommType} | ConvertTo-Json -Compress) -TokenKey $TassTokenKey).users | Where-Object username
# $TassCurrentEmployees = (Submit-TASSApiRequest -Endpoint $TassEndpoint -Method 'getEmployees' -AppCode $TassAppCode -CompanyCode $TassCompanyCode -ApiVersion $TassApiVersion -Parameters '{"currentstatus":"current"}' -TokenKey $TassTokenKey).users | Where-Object username

Write-Host "Processing contacts data..."
$ConcordContacts = New-Object System.Collections.Generic.List[PSCustomObject]
StudentContacts $TassCurrentStudents $ConcordContacts

# $ConcordPatrons = New-Object System.Collections.Generic.List[PSCustomObject]
# StudentPatrons $TassCurrentStudents $ConcordPatrons


$ConcordContacts | Select-Object -Property * -Unique | Export-Csv $tempCsv -NoTypeInformation # Yes, Select-Object is slower than Sort-Object. But it maintains order. There is an open GitHub issue on PS Core repo to make Select faster
# PS 5.1 seems to need -NoTypeInformation here, worked fine without it on macOS PS Core 6

$ConcordCredential = New-Object PSCredential ($ConcordUsername, (ConvertTo-SecureString $ConcordPassword -AsPlainText -Force))

Write-Host "Uploading data to Concord Infiniti..."
try {
    Invoke-RestMethod -Uri "https://$ConcordDomain/api/import/userContacts/$ConcordContactsMode" -Method Post -Authentication Basic -Credential $ConcordCredential -Form @{ file = Get-Item $tempCsv }
    Write-Host "Done!"
} catch [Exception] {
    Write-Host "Error connecting to $uri"
    Write-Host $_.Exception.Message
} finally {
    Remove-Item $tempCsv
}
