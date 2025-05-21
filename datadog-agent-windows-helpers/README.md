# Datadog Agent Encrypted Secret Backend for Windows

This PowerShell module provides secure secret management for the Datadog Agent on Windows systems.

## Overview

datadog_helpers.ps1 enables secure storage and retrieval of encrypted secrets for use with the Datadog Agent's `secret_backend_command` feature. The script offers:

- Encryption and decryption of sensitive values
- Secure storage of encrypted secrets as files
- A secret backend implementation compatible with Datadog Agent

## Installation

1. Create the required directories:
```powershell
New-Item -ItemType Directory -Force -Path "C:\ProgramData\Datadog"
```

2. Copy datadog_helpers.ps1 to a secure location, such as:
```powershell
Copy-Item datadog_helpers.ps1 "C:\ProgramData\Datadog\"
```

3. Generate a master password file:
```powershell
$password = ConvertTo-SecureString -AsPlainText "YourStrongPassword" -Force
$password | ConvertFrom-SecureString | Out-File "C:\ProgramData\Datadog\secret_password"
```

4. Set appropriate permissions:
```powershell
$acl = Get-Acl "C:\ProgramData\Datadog\secret_password"
$acl.SetAccessRuleProtection($true, $false)

$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\SYSTEM", "FullControl", "Allow")
$acl.AddAccessRule($rule)

$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "Allow")
$acl.AddAccessRule($rule)

$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("NT SERVICE\datadogagent", "Read", "Allow")
$acl.AddAccessRule($rule)

$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("ddagentuser", "Read", "Allow")
$acl.AddAccessRule($rule)

Set-Acl "C:\ProgramData\Datadog\secret_password" $acl
```

## Usage

### (Optional) For Unsigned Script

You might need to allow a powershell script, example allow Unrestricted for Users or Current Process

```powershell
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process

# TODO: Set for Datadog user
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process
```

### Encrypting and Storing Secrets

```powershell
cd C:\ProgramData\Datadog\

# Store an API key
.\datadog_helpers.ps1 Encrypt-And-Store-Secret api_key "your-api-key-here"

# Store a database password
.\datadog_helpers.ps1 Encrypt-And-Store-Secret db_password "your-database-password"
```

### Configuring Datadog Agent

```powershell
# Create a secure directory
New-Item -ItemType Directory -Force -Path "C:\ProgramData\Datadog\secure"

# Create a simple batch wrapper for PowerShell
@"
@echo off
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File "C:\ProgramData\Datadog\datadog_helpers.ps1" %*
"@ | Out-File -FilePath "C:\ProgramData\Datadog\secure\run_helper.bat" -Encoding ascii

# Set restrictive permissions on the wrapper
$acl = New-Object System.Security.AccessControl.FileSecurity
$acl.SetAccessRuleProtection($true, $false)

# Allow only SYSTEM, Administrators and the specific SID mentioned in error
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\SYSTEM", "FullControl", "Allow")
$acl.AddAccessRule($rule)

$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "Allow")
$acl.AddAccessRule($rule)

# Add the specific SID from your error message
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("ddagentuser", "FullControl", "Allow")
$acl.AddAccessRule($rule)

Set-Acl "C:\ProgramData\Datadog\secure\run_helper.bat" $acl
```

Update your Datadog Agent configuration file (`datadog.yaml`):

```yaml
secret_backend_command: powershell -ExecutionPolicy Bypass -File C:\ProgramData\Datadog\datadog_helpers.ps1
```

Restart the Datadog Agent to apply changes:

```powershell
Restart-Service -Name datadogagent
```

## How It Works

1. The script uses AES encryption to protect secrets
2. Encrypted secrets are stored as individual files in the script directory
3. When Datadog Agent needs a secret, it calls this script
4. The script decrypts requested secrets and returns them in JSON format

## Security Considerations

- The master password file should be kept secure with restrictive permissions
- For enhanced security, consider storing the script and secrets on an encrypted volume
- Regularly update the master password and re-encrypt secrets

## Troubleshooting

Logs are written to `C:\ProgramData\Datadog\datadog_helpers.log` to help diagnose issues with the script.

Common issues:
- Permission denied: Ensure proper file permissions are set
- Missing password file: Verify the secret_password file exists
- Decryption failed: Check if the correct password was used for encryption
