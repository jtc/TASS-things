# Function to generate encrypted token to use in the API call.
function Get-TASSEncryptedToken($TokenKey, $Parameters) {
    # Convert encryption token from Base64 encoding to byte array.
    $keyArray = [System.Convert]::FromBase64String($TokenKey)

    # Store the string to be encrypted as a byte array.
    $toEncryptArray = [System.Text.Encoding]::UTF8.GetBytes($Parameters)

    # Create a cryptography object with the necessary settings.
    $rDel = New-Object System.Security.Cryptography.RijndaelManaged
    $rDel.Key = $keyArray
    $rDel.Mode = [System.Security.Cryptography.CipherMode]::ECB
    $rDel.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $rDel.BlockSize = 128;

    # Encrypt, return as a byte array, and convert to a Base 64 encoded string. 
    $cTransform = $rDel.CreateEncryptor($keyArray, $null)
    [byte[]]$resultArray = $cTransform.TransformFinalBlock($toEncryptArray, 0, $toEncryptArray.Length)
    $resultBase64 = [System.Convert]::ToBase64String($resultArray, 0, $resultArray.Length)

    # Return as Base 64 encoded string. 
    return $resultBase64
}

# Function to POST an API request to TASS
function Submit-TASSApiRequest ($Endpoint, $Method, $AppCode, $CompanyCode, $ApiVersion, $Parameters, $TokenKey) {
    # Encrypt the token.
    $encryptedToken = Get-TASSEncryptedToken -tokenKey $TokenKey -parameters $Parameters

    # Build the request body
    $body = @{
        method = $Method
        appcode = $AppCode
        company = $CompanyCode
        v = $ApiVersion
        token = $encryptedToken
    }

    # Invoke REST request
    return Invoke-RestMethod -Method Post -Uri $Endpoint -Body $body
}
