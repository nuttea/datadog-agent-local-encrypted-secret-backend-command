#!/usr/bin/env bats

# Setup - runs before each test
setup() {
    # Create temp directory for test files
    TEST_DIR=$(mktemp -d)
    TEST_PASSWORD_FILE="${TEST_DIR}/secret_password"
    TEST_SECRET_FILE="${TEST_DIR}/test_secret"
    TEST_PASSWORD="testpassword123"
    TEST_SECRET="mysecretvalue"
    
    # Copy the script to test directory
    cp "${BATS_TEST_DIRNAME}/../datadog_helpers.sh" "${TEST_DIR}/"
    chmod +x "${TEST_DIR}/datadog_helpers.sh"
    
    # Create test password file
    echo -n "${TEST_PASSWORD}" > "${TEST_PASSWORD_FILE}"
    
    # Mock LOG_FILE to avoid permission issues during tests
    export LOG_FILE="${TEST_DIR}/test.log"
}

# Teardown - runs after each test
teardown() {
    # Clean up test directory
    rm -rf "${TEST_DIR}"
}

# Test the encrypt_text and decrypt_text functions
@test "encrypt and decrypt text" {
    # Encrypt text
    local encrypted=$(${TEST_DIR}/datadog_helpers.sh encrypt "plaintext" "${TEST_PASSWORD}")
    encrypted=${encrypted#"Encrypted text: "}
    
    # Decrypt text
    local decrypted=$(${TEST_DIR}/datadog_helpers.sh decrypt "${encrypted}" "${TEST_PASSWORD}")
    decrypted=${decrypted#"Decrypted text: "}
    
    # Assert decryption worked correctly
    [ "${decrypted}" = "plaintext" ]
}

# Test encrypt_and_store_secret function
@test "encrypt_and_store_secret stores encrypted secret" {
    # Set environment variables to use test directory
    export password_file="${TEST_PASSWORD_FILE}"
    
    # Run the function
    cd "${TEST_DIR}"
    run ${TEST_DIR}/datadog_helpers.sh encrypt_and_store_secret "test_secret" "${TEST_SECRET}"
    
    # Assert command succeeded
    [ "$status" -eq 0 ]
    
    # Check if file exists
    [ -f "${TEST_DIR}/test_secret" ]
    
    # Check file permissions
    perms=$(stat -c %a "${TEST_DIR}/test_secret" 2>/dev/null || stat -f "%Lp" "${TEST_DIR}/test_secret")
    [[ "$perms" == "600" || "$perms" == "400" ]]
    
    # Verify we can decrypt the content
    local encrypted=$(cat "${TEST_DIR}/test_secret")
    local decrypted=$(${TEST_DIR}/datadog_helpers.sh decrypt "${encrypted}" "${TEST_PASSWORD}")
    decrypted=${decrypted#"Decrypted text: "}
    [ "${decrypted}" = "${TEST_SECRET}" ]
}

# Test secret backend with mocked JSON input
@test "datadog_secret_backend correctly processes secrets" {
    # Create test secret
    cd "${TEST_DIR}"
    ${TEST_DIR}/datadog_helpers.sh encrypt_and_store_secret "test_secret" "${TEST_SECRET}"
    
    # Create input JSON for secret backend
    echo '{"version": "1.0", "secrets": ["test_secret"]}' > "${TEST_DIR}/input.json"
    
    # Mock the environment for datadog_secret_backend
    export password_file="${TEST_PASSWORD_FILE}"
    
    # Run the secret backend command
    cd "${TEST_DIR}"
    run bash -c "cat ${TEST_DIR}/input.json | ${TEST_DIR}/datadog_helpers.sh --secret-backend"
    
    # Assert command succeeded
    [ "$status" -eq 0 ]
    
    # Check output is valid JSON with expected format
    echo "Output: $output"
    echo "$output" | grep -q '"test_secret": {"value": "mysecretvalue", "error": null}'
}

# Test error handling when password file is missing
@test "encrypt_and_store_secret fails when password file is missing" {
    # Remove password file
    rm "${TEST_PASSWORD_FILE}"
    
    # Run the function
    cd "${TEST_DIR}"
    run ${TEST_DIR}/datadog_helpers.sh encrypt_and_store_secret "test_secret" "${TEST_SECRET}"
    
    # Assert command failed
    [ "$status" -eq 1 ]
    
    # Check error message
    echo "Output: $output"
    echo "$output" | grep -q "Password file not found"
}

# Test handling of invalid JSON in datadog_secret_backend
@test "datadog_secret_backend handles invalid JSON input" {
    # Create invalid JSON for secret backend
    echo 'invalid json' > "${TEST_DIR}/invalid.json"
    
    # Run the secret backend command with invalid input
    cd "${TEST_DIR}"
    run bash -c "cat ${TEST_DIR}/invalid.json | ${TEST_DIR}/datadog_helpers.sh --secret-backend"
    
    # Check output - should be empty JSON on error
    echo "Output: $output"
    [ "$output" = "{}" ]
}

# Test handling of missing secret files in datadog_secret_backend
@test "datadog_secret_backend reports error for missing secret files" {
    # Create input JSON requesting non-existent secret
    echo '{"version": "1.0", "secrets": ["nonexistent_secret"]}' > "${TEST_DIR}/input.json"
    
    # Mock the environment for datadog_secret_backend
    export password_file="${TEST_PASSWORD_FILE}"
    
    # Run the secret backend command
    cd "${TEST_DIR}"
    run bash -c "cat ${TEST_DIR}/input.json | ${TEST_DIR}/datadog_helpers.sh --secret-backend"
    
    # Assert command succeeded but reports error for missing file
    [ "$status" -eq 0 ]
    echo "Output: $output"
    echo "$output" | grep -q '"nonexistent_secret": {"value": null, "error": "file not found"}'
}

# Test script functioning in secret backend mode when called with no args
@test "script runs in secret backend mode when called with no arguments" {
    # Create a mock password file
    echo -n "${TEST_PASSWORD}" > "${TEST_DIR}/secret_password"
    
    # Create input JSON for secret backend
    echo '{"version": "1.0", "secrets": []}' > "${TEST_DIR}/input.json"
    
    # Run the script with no arguments, providing JSON input
    cd "${TEST_DIR}"
    run bash -c "cat ${TEST_DIR}/input.json | ${TEST_DIR}/datadog_helpers.sh"
    
    # Should return empty JSON (with no secrets)
    echo "Output: $output"
    [ "$output" = "{}" ]
}

# Test handling multiple secrets in one request
@test "datadog_secret_backend handles multiple secrets" {
    # Create test secrets
    cd "${TEST_DIR}"
    ${TEST_DIR}/datadog_helpers.sh encrypt_and_store_secret "secret1" "value1"
    ${TEST_DIR}/datadog_helpers.sh encrypt_and_store_secret "secret2" "value2"
    
    # Create input JSON for secret backend
    echo '{"version": "1.0", "secrets": ["secret1", "secret2"]}' > "${TEST_DIR}/input.json"
    
    # Run the secret backend command
    cd "${TEST_DIR}"
    run bash -c "cat ${TEST_DIR}/input.json | ${TEST_DIR}/datadog_helpers.sh --secret-backend"
    
    # Check both secrets are in the output
    echo "Output: $output"
    echo "$output" | grep -q '"secret1": {"value": "value1", "error": null}'
    echo "$output" | grep -q '"secret2": {"value": "value2", "error": null}'
}

# Test script usage with invalid action
@test "script shows usage when called with invalid action" {
    run ${TEST_DIR}/datadog_helpers.sh invalid_action "text" "password"
    
    # Check usage message contains expected commands
    echo "Output: $output"
    echo "$output" | grep -q "Usage:"
    echo "$output" | grep -q "encrypt <text> <password>"
    echo "$output" | grep -q "decrypt <base64_encrypted_text> <password>"
    echo "$output" | grep -q "encrypt_and_store_secret <secret_name> <secret_value>"
}