$ErrorActionPreference = 'Stop'
$project = 'demo-noteflow'
$auth = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1'
$firestore = "http://127.0.0.1:8080/v1/projects/$project/databases/(default)/documents"
$run = [Guid]::NewGuid().ToString('N')
$email = "avatar-$run@example.test"
$originalPassword = [Guid]::NewGuid().ToString('N')
$newPassword = [Guid]::NewGuid().ToString('N')

function Send-AuthRequest($action, $body) {
    Invoke-RestMethod -Method Post -Uri "$auth/accounts:${action}?key=$project" `
        -ContentType 'application/json' -Body ($body | ConvertTo-Json -Compress)
}

function Get-EmailCode($address, $requestType) {
    $codes = Invoke-RestMethod "http://127.0.0.1:9099/emulator/v1/projects/$project/oobCodes"
    $matching = $codes.oobCodes | Where-Object { $_.email -eq $address -and $_.requestType -eq $requestType }
    if (@($matching).Count -ne 1) {
        throw "Expected one $requestType code from the Auth emulator."
    }
    $matching.oobCode
}

function Test-ResponseStatus($actual, $expected, $scenario) {
    if ([int]$actual.StatusCode -ne $expected) {
        throw "$scenario returned HTTP $($actual.StatusCode). Expected $expected."
    }
}

function Send-AvatarRequest($method, $account, $body) {
    $parameters = @{
        Method = $method
        Uri = "$firestore/accountAvatars/$($owner.localId)"
        Headers = @{ Authorization = "Bearer $($account.idToken)" }
        SkipHttpErrorCheck = $true
    }
    if ($null -ne $body) {
        $parameters.ContentType = 'application/json'
        $parameters.Body = $body | ConvertTo-Json -Compress -Depth 8
    }
    Invoke-WebRequest @parameters
}

$owner = Send-AuthRequest 'signUp' @{
    email = $email; password = $originalPassword; returnSecureToken = $true
}
$other = Send-AuthRequest 'signUp' @{
    email = "other-$run@example.test"; password = $originalPassword; returnSecureToken = $true
}
$before = Send-AuthRequest 'lookup' @{ idToken = $owner.idToken }
if ($before.users[0].emailVerified) { throw 'New emulator account was already verified.' }
Send-AuthRequest 'sendOobCode' @{ requestType = 'VERIFY_EMAIL'; idToken = $owner.idToken } | Out-Null
$verified = Send-AuthRequest 'update' @{ oobCode = Get-EmailCode $email 'VERIFY_EMAIL' }
if (!$verified.emailVerified) { throw 'Verification did not activate the account.' }

Send-AuthRequest 'sendOobCode' @{ requestType = 'PASSWORD_RESET'; email = $email } | Out-Null
Send-AuthRequest 'resetPassword' @{
    oobCode = Get-EmailCode $email 'PASSWORD_RESET'; newPassword = $newPassword
} | Out-Null
$oldLogin = Invoke-WebRequest -Method Post -Uri "$auth/accounts:signInWithPassword?key=$project" `
    -ContentType 'application/json' -SkipHttpErrorCheck `
    -Body (@{ email = $email; password = $originalPassword; returnSecureToken = $true } | ConvertTo-Json -Compress)
Test-ResponseStatus $oldLogin 400 'Sign-in with the previous password'
$signIn = @{ email = $email; password = $newPassword; returnSecureToken = $true }
$ownerSession = Send-AuthRequest 'signInWithPassword' $signIn
$otherOwnerSession = Send-AuthRequest 'signInWithPassword' $signIn
Write-Output 'Auth emulator: registration, activation, reset and manual sign-in passed.'

$png = 'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAdSURBVDhPY0iZ+vY/JZgBXYBUPGrAqAGjBgwWAwBvsOUfyEymUQAAAABJRU5ErkJggg=='
$avatar = @{ fields = @{ active = @{ booleanValue = $true }; png = @{ bytesValue = $png } } }
$reset = @{ fields = @{ active = @{ booleanValue = $false } } }

Test-ResponseStatus (Send-AvatarRequest 'GET' $ownerSession) 404 'Avatar before first upload'
Test-ResponseStatus (Send-AvatarRequest 'PATCH' $ownerSession $avatar) 200 'Owner avatar upload'
Test-ResponseStatus (Send-AvatarRequest 'GET' $other) 403 'Cross-account avatar read'
Test-ResponseStatus (Send-AvatarRequest 'PATCH' $other $reset) 403 'Cross-account avatar update'
$reloaded = Send-AvatarRequest 'GET' $otherOwnerSession
Test-ResponseStatus $reloaded 200 'Owner avatar on a second session'
if (($reloaded.Content | ConvertFrom-Json).fields.png.bytesValue -ne $png) {
    throw 'The second owner session did not receive the saved avatar.'
}
$invalid = @{ fields = @{ active = @{ booleanValue = $true }; png = @{ stringValue = 'not bytes' } } }
Test-ResponseStatus (Send-AvatarRequest 'PATCH' $ownerSession $invalid) 403 'Malformed avatar document'
Test-ResponseStatus (Send-AvatarRequest 'PATCH' $ownerSession $reset) 200 'Owner avatar reset'
$cleared = Send-AvatarRequest 'GET' $otherOwnerSession
Test-ResponseStatus $cleared 200 'Reset avatar on a second session'
$fields = ($cleared.Content | ConvertFrom-Json).fields
if ($fields.active.booleanValue -or $fields.PSObject.Properties.Name -contains 'png') {
    throw 'Reset avatar still contains image data.'
}
Write-Output 'Firestore emulator: owner access, cross-account denial, invalid data, and reset passed.'
