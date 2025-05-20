# datadog_helpers.ps1

param (
    [Parameter(Position=0)]
    [string]$Action,
    
    [Parameter(Position=1)]
    [string]$Arg1,

    [Parameter(Position=2)]
    [string]$Arg2
)

# Global config
$PasswordFile = "C:\ProgramData\Datadog\secret_password.txt"
$ErrorActionPreference = "Stop"

function Encrypt-Text {
    param (
        [string]$PlainText,
        [string]$Password
    )
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
    $secureString = ConvertTo-SecureString -String $Password -AsPlainText -Force
    $encrypted = ConvertFrom-SecureString -SecureString ($bytes | ConvertTo-SecureString -AsPlainText -Force) -SecureKey $secureString
    return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($encrypted))
}

function Decrypt-Text {
    param (
        [string]$EncryptedBase64,
        [string]$Password
    )
    try {
        $decoded = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($EncryptedBase64))
        $secureString = ConvertTo-SecureString -String $Password -AsPlainText -Force
        $decrypted = ConvertTo-SecureString -String $decoded -SecureKey $secureString
        return ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($decrypted)))
    } catch {
        return $null
    }
}

function Encrypt-And-Store-Secret {
    param (
        [string]$SecretName,
        [string]$SecretValue
    )

    if (!(Test-Path $PasswordFile)) {
        Write-Error "Password file not found: $PasswordFile"
        exit 1
    }

    $password = Get-Content $PasswordFile -Raw
    $encrypted = Encrypt-Text -PlainText $SecretValue -Password $password
    if ($null -ne $encrypted) {
        Set-Content -Path $SecretName -Value $encrypted -Encoding ASCII
        Write-Output "Secret saved: $SecretName"
    } else {
        Write-Error "Encryption failed for $SecretName"
        exit 1
    }
}

function Invoke-Datadog-SecretBackend {
    if (!(Test-Path $PasswordFile)) {
        Write-Error "Missing password file"
        exit 1
    }

    $password = Get-Content $PasswordFile -Raw
    $inputJson = Get-Content -Raw

    $parsed = $null
    try {
        $parsed = $inputJson | ConvertFrom-Json
    } catch {
        Write-Error "Invalid JSON input"
        exit 1
    }

    $result = @{}
    foreach ($secret in $parsed.secrets) {
        if (Test-Path $secret) {
            $encrypted = Get-Content $secret -Raw
            $decrypted = Decrypt-Text -EncryptedBase64 $encrypted -Password $password
            if ($decrypted) {
                $result[$secret] = @{ value = $decrypted; error = $null }
            } else {
                $result[$secret] = @{ value = $null; error = "decryption failed" }
            }
        } else {
            $result[$secret] = @{ value = $null; error = "file not found" }
        }
    }

    $output = $result | ConvertTo-Json -Depth 5
    Write-Output $output
}

# Main CLI logic
switch ($Action) {
    "encrypt" {
        if ($Arg1 -and $Arg2) {
            $out = Encrypt-Text -PlainText $Arg1 -Password $Arg2
            Write-Output "Encrypted text: $out"
        } else {
            Write-Output "Usage: encrypt <text> <password>"
        }
    }
    "decrypt" {
        if ($Arg1 -and $Arg2) {
            $out = Decrypt-Text -EncryptedBase64 $Arg1 -Password $Arg2
            Write-Output "Decrypted text: $out"
        } else {
            Write-Output "Usage: decrypt <base64_encrypted_text> <password>"
        }
    }
    "encrypt_and_store_secret" {
        if ($Arg1 -and $Arg2) {
            Encrypt-And-Store-Secret -SecretName $Arg1 -SecretValue $Arg2
        } else {
            Write-Output "Usage: encrypt_and_store_secret <secret_name> <secret_value>"
        }
    }
    "--secret-backend" {
        Invoke-Datadog-SecretBackend
    }
    default {
        Write-Output "Usage:"
        Write-Output "  .\datadog_helpers.ps1 encrypt <text> <password>"
        Write-Output "  .\datadog_helpers.ps1 decrypt <base64_text> <password>"
        Write-Output "  .\datadog_helpers.ps1 encrypt_and_store_secret <secret_name> <secret_value>"
        Write-Output "  .\datadog_helpers.ps1 --secret-backend"
    }
}
