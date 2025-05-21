# filepath: /datadog-agent-powershell-helpers/datadog-agent-powershell-helpers/tests/Test-DatadogHelpers.ps1

# Import the module containing the functions to be tested
Import-Module ..\datadog_helpers.ps1

# Define a function to test the logging functionality
function Test-Logging {
    # Arrange
    $logFilePath = "C:\path\to\log\file.log" # Update this path as needed
    Clear-Content -Path $logFilePath -ErrorAction SilentlyContinue

    # Act
    log "Test log entry"

    # Assert
    $logContents = Get-Content -Path $logFilePath
    if ($logContents -notlike "*Test log entry*") {
        throw "Logging test failed: Log entry not found."
    }
}

# Define a function to test encryption and decryption
function Test-EncryptionDecryption {
    # Arrange
    $password = "TestPassword"
    $originalText = "SecretData"
    
    # Act
    $encryptedText = encrypt_text $originalText $password
    $decryptedText = decrypt_text $encryptedText $password

    # Assert
    if ($decryptedText -ne $originalText) {
        throw "Encryption/Decryption test failed: Decrypted text does not match original."
    }
}

# Define a function to run all tests
function Run-Tests {
    Test-Logging
    Test-EncryptionDecryption
    Write-Host "All tests passed successfully."
}

# Execute the tests
Run-Tests