# filepath: /datadog-agent-powershell-helpers/datadog-agent-powershell-helpers/datadog_helpers.ps1

function Log {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = "C:\ProgramData\Datadog\datadog_helpers.log"
    "$timestamp $Message" | Out-File -FilePath $logFile -Append -ErrorAction SilentlyContinue
}

function Encrypt-Text {
    param (
        [string]$Text,
        [string]$Password
    )
    Log "Encrypting text (length: $($Text.Length))"
    
    try {
        # Convert the password to a valid 256-bit key using SHA256
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $key = $sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($Password))
        
        # Create a consistent IV from the first 16 bytes of SHA256(password + "IV")
        $ivInput = $Password + "IV"
        $iv = $sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($ivInput))[0..15]
        
        # Create AES encryptor with proper key and IV
        $aes = [System.Security.Cryptography.Aes]::Create()
        $encryptor = $aes.CreateEncryptor($key, $iv)
        
        # Encrypt the data
        $plaintextBytes = [Text.Encoding]::UTF8.GetBytes($Text)
        $encryptedBytes = $encryptor.TransformFinalBlock($plaintextBytes, 0, $plaintextBytes.Length)
        
        # Clean up
        $encryptor.Dispose()
        $aes.Dispose()
        
        # Return as Base64 string
        return [Convert]::ToBase64String($encryptedBytes)
    }
    catch {
        Log "ERROR: Encryption failed: $_"
        return $null
    }
}

function Decrypt-Text {
    param (
        [string]$EncryptedText,
        [string]$Password
    )
    Log "Decrypting text (length: $($EncryptedText.Length))"
    
    try {
        # Convert the password to a valid 256-bit key using SHA256
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $key = $sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($Password))
        
        # Create a consistent IV from the first 16 bytes of SHA256(password + "IV")
        $ivInput = $Password + "IV"
        $iv = $sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($ivInput))[0..15]
        
        # Create AES decryptor with proper key and IV
        $aes = [System.Security.Cryptography.Aes]::Create()
        $decryptor = $aes.CreateDecryptor($key, $iv)
        
        # Decrypt the data
        $encryptedBytes = [Convert]::FromBase64String($EncryptedText)
        $decryptedBytes = $decryptor.TransformFinalBlock($encryptedBytes, 0, $encryptedBytes.Length)
        
        # Clean up
        $decryptor.Dispose()
        $aes.Dispose()
        
        # Return as string
        return [Text.Encoding]::UTF8.GetString($decryptedBytes)
    }
    catch {
        Log "ERROR: Decryption failed: $_"
        throw
    }
}

function Encrypt-And-Store-Secret {
    param (
        [string]$SecretName,
        [string]$SecretValue
    )
    $passwordFile = "C:\ProgramData\Datadog\secret_password"
    
    Log "Encrypting and storing secret: $SecretName"

    if (-Not (Test-Path $passwordFile)) {
        Log "ERROR: Password file not found: $passwordFile"
        Write-Error "Password file not found: $passwordFile"
        return $false
    }

    $password = Get-Content $passwordFile
    Log "Password file loaded successfully"

    $encrypted = Encrypt-Text -Text $SecretValue -Password $password
    if ($encrypted) {
        Set-Content -Path $SecretName -Value $encrypted -Force
        Log "Secret successfully encrypted and saved to: $SecretName"
        Write-Output "Secret encrypted and saved to: $SecretName"
    } else {
        Log "ERROR: Encryption failed for $SecretName"
        Write-Error "Encryption failed for $SecretName"
        return $false
    }
}

function Datadog-Secret-Backend {
    $passwordFile = "C:\ProgramData\Datadog\secret_password"

    Log "Secret backend mode activated"

    if (-Not (Test-Path $passwordFile)) {
        Log "ERROR: Missing password file"
        Write-Error "Missing password file"
        exit 1
    }

    $password = Get-Content $passwordFile
    Log "Password file loaded successfully"

    $inputJson = Get-Content -Raw -Path "php://stdin"
    Log "Received input JSON"

    $secretNames = (ConvertFrom-Json $inputJson).secrets
    if (-Not $secretNames) {
        Log "ERROR: Failed to parse input JSON"
        Write-Output "{}"
        exit 1
    }

    Log "Processing secrets: $($secretNames -join ', ')"

    $output = @{}

    foreach ($secret in $secretNames) {
        Log "Processing secret: $secret"
        $secretFile = "C:\ProgramData\Datadog\$secret"
        if (Test-Path $secretFile) {
            Log "Secret file found: $secretFile"
            $encryptedValue = Get-Content $secretFile
            try {
                $decryptedValue = Decrypt-Text -EncryptedText $encryptedValue -Password $password
                Log "Successfully decrypted secret: $secret"
                $output[$secret] = @{ value = $decryptedValue; error = $null }
            } catch {
                Log "ERROR: Failed to decrypt secret: $secret"
                $output[$secret] = @{ value = $null; error = "decryption failed" }
            }
        } else {
            Log "ERROR: Secret file not found: $secretFile"
            $output[$secret] = @{ value = $null; error = "file not found" }
        }
    }

    Log "Returning JSON response"
    $output | ConvertTo-Json -Depth 10
}

# Main script execution
if ($args.Count -eq 0 -or $args[0] -eq '--secret-backend') {
    Log "Starting secret backend mode"
    Datadog-Secret-Backend
    Log "Secret backend processing complete"
    exit 0
}

if ($args[0] -eq 'Encrypt-And-Store-Secret' -and $args.Count -eq 3) {
    Log "Starting Encrypt-And-Store-Secret with name: $args[1]"
    Encrypt-And-Store-Secret -SecretName $args[1] -SecretValue $args[2]
    exit $LASTEXITCODE
}

if ($args.Count -ne 3) {
    Log "Invalid arguments, showing usage"
    Write-Output "Usage:"
    Write-Output "  .\$($MyInvocation.MyCommand.Name) Encrypt <text> <password>"
    Write-Output "  .\$($MyInvocation.MyCommand.Name) Decrypt <base64_encrypted_text> <password>"
    Write-Output "  .\$($MyInvocation.MyCommand.Name) Encrypt-And-Store-Secret <secret_name> <secret_value>"
    Write-Output "  .\$($MyInvocation.MyCommand.Name) --secret-backend"
    Write-Output "  .\$($MyInvocation.MyCommand.Name) (no args, equivalent to --secret-backend)"
    exit 1
}

$action = $args[0]
$text = $args[1]
$password = $args[2]

Log "Processing action: $action"

switch ($action) {
    'Encrypt' {
        Log "Encrypting text (length: $($text.Length))"
        $encryptedText = Encrypt-Text -Text $text -Password $password
        Write-Output "Encrypted text: $encryptedText"
        Log "Encryption completed successfully"
    }
    'Decrypt' {
        Log "Decrypting text (length: $($text.Length))"
        $decryptedText = Decrypt-Text -EncryptedText $text -Password $password
        Write-Output "Decrypted text: $decryptedText"
        Log "Decryption completed successfully"
    }
    default {
        Log "ERROR: Invalid action: $action"
        Write-Error "Invalid action: $action"
        exit 1
    }
}

Log "Script execution completed successfully"