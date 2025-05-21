#!/bin/bash

# Define log function and log file
LOG_FILE="/var/log/datadog/datadog_helpers.log"

log() {
  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  local message="$1"
  echo "[$timestamp] $message" >> "$LOG_FILE" 2>/dev/null || true
}

log "Script started with args: $*"

# Function to encrypt text
encrypt_text() {
  local text="$1"
  local password="$2"
  log "Encrypting text (length: ${#text})"
  openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -pass "pass:$password" <<< "$text" | base64
}

# Function to decrypt base64-encoded encrypted text
decrypt_text() {
  local encrypted_text="$1"
  local password="$2"
  log "Decrypting text (length: ${#encrypted_text})"
  echo "$encrypted_text" | base64 -d | openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter 100000 -pass "pass:$password"
}

# Helper function to encrypt and save a secret to a file
encrypt_and_store_secret() {
  local secret_name="$1"
  local secret_value="$2"
  local password_file="/etc/datadog-agent/secret_password"

  log "Encrypting and storing secret: $secret_name"

  if [[ ! -f "$password_file" ]]; then
    log "ERROR: Password file not found: $password_file"
    echo "Password file not found: $password_file" >&2
    return 1
  fi

  local password
  password=$(<"$password_file")
  log "Password file loaded successfully"

  encrypted=$(encrypt_text "$secret_value" "$password")
  if [[ -n "$encrypted" ]]; then
    echo -n "$encrypted" > "$secret_name"
    chmod 600 "$secret_name"
    chown dd-agent:dd-agent "$secret_name" 2>/dev/null || true
    log "Secret successfully encrypted and saved to: $secret_name"
    echo "Secret encrypted and saved to: $secret_name"
  else
    log "ERROR: Encryption failed for $secret_name"
    echo "Encryption failed for $secret_name" >&2
    return 1
  fi
}

# Function used by Datadog secret_backend_command
datadog_secret_backend() {
  local password_file="/etc/datadog-agent/secret_password"
  local password

  log "Secret backend mode activated"

  if [[ ! -f "$password_file" ]]; then
    log "ERROR: Missing password file"
    echo "Missing password file" >&2
    exit 1
  fi

  password=$(<"$password_file")
  log "Password file loaded successfully"

  # Read JSON input from stdin
  read -r input_json
  log "Received input JSON"

  # Extract the list of secrets using jq
  secret_names=$(echo "$input_json" | jq -r '.secrets[]' 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    log "ERROR: Failed to parse input JSON with jq"
    echo "{}" # Return empty JSON on error
    exit 1
  fi
  
  log "Processing secrets: $secret_names"

  # Prepare output JSON
  output="{"

  for secret in $secret_names; do
    log "Processing secret: $secret"
    secret_file="/etc/datadog-agent/$secret"
    if [[ -f "$secret_file" ]]; then
      log "Secret file found: $secret_file"
      encrypted_value=$(<"$secret_file")
      if decrypted_value=$(decrypt_text "$encrypted_value" "$password" 2>/dev/null); then
        log "Successfully decrypted secret: $secret"
        output+="\"$secret\": {\"value\": \"${decrypted_value//\"/\\\"}\", \"error\": null},"
      else
        log "ERROR: Failed to decrypt secret: $secret"
        output+="\"$secret\": {\"value\": null, \"error\": \"decryption failed\"},"
      fi
    else
      log "ERROR: Secret file not found: $secret_file"
      output+="\"$secret\": {\"value\": null, \"error\": \"file not found\"},"
    fi
  done

  # Trim trailing comma and close JSON
  output="${output%,}}"
  log "Returning JSON response"
  echo "$output"
}

log "Parsing command line arguments"

# If called with --secret-backend (Datadog mode) or with no arguments
if [[ "$1" == "--secret-backend" || $# -eq 0 ]]; then
  log "Starting secret backend mode"
  datadog_secret_backend
  log "Secret backend processing complete"
  exit 0
fi

# Command-line interface
if [[ "$1" == "encrypt_and_store_secret" && $# -eq 3 ]]; then
  log "Starting encrypt_and_store_secret with name: $2"
  encrypt_and_store_secret "$2" "$3"
  result=$?
  log "encrypt_and_store_secret completed with exit code: $result"
  exit $result
fi

# Legacy encrypt/decrypt usage
if [[ $# -ne 3 ]]; then
  log "Invalid arguments, showing usage"
  echo "Usage:"
  echo "  $0 encrypt <text> <password>"
  echo "  $0 decrypt <base64_encrypted_text> <password>"
  echo "  $0 encrypt_and_store_secret <secret_name> <secret_value>"
  echo "  $0 --secret-backend"
  echo "  $0 (no args, equivalent to --secret-backend)"
  exit 1
fi

action="$1"
text="$2"
password="$3"

log "Processing action: $action"

case "$action" in
  encrypt)
    log "Encrypting text (length: ${#text})"
    encrypted_text=$(encrypt_text "$text" "$password")
    echo "Encrypted text: $encrypted_text"
    log "Encryption completed successfully"
    ;;
  decrypt)
    log "Decrypting text (length: ${#text})"
    decrypted_text=$(decrypt_text "$text" "$password")
    echo "Decrypted text: $decrypted_text"
    log "Decryption completed successfully"
    ;;
  *)
    log "ERROR: Invalid action: $action"
    echo "Invalid action: $action"
    exit 1
    ;;
esac

log "Script execution completed successfully"