# datadog-agent-powershell-helpers

## Overview
This project provides a set of PowerShell functions for managing secrets in a secure manner. It includes functionalities for encrypting and decrypting secrets, as well as logging operations for better traceability.

## Prerequisites
- PowerShell 5.1 or later
- OpenSSL installed on your system for encryption and decryption operations

## Usage
### Encrypting a Secret
To encrypt a secret, use the `Encrypt-Secret` function:
```powershell
$encryptedSecret = Encrypt-Secret -Text "YourSecretValue" -Password "YourPassword"
```

### Decrypting a Secret
To decrypt a previously encrypted secret, use the `Decrypt-Secret` function:
```powershell
$decryptedSecret = Decrypt-Secret -EncryptedText $encryptedSecret -Password "YourPassword"
```

### Logging
All operations are logged to a specified log file. Ensure that the log file path is writable by the script.

## Examples
```powershell
# Encrypt a secret
$encrypted = Encrypt-Secret -Text "MySuperSecret" -Password "StrongPassword"

# Decrypt the secret
$decrypted = Decrypt-Secret -EncryptedText $encrypted -Password "StrongPassword"
```

## Testing
Unit tests for the functions are located in the `tests` directory. You can run the tests using the following command:
```powershell
Invoke-Pester -Path .\tests\Test-DatadogHelpers.ps1
```

## License
This project is licensed under the MIT License. See the LICENSE file for details.