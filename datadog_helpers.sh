#!/bin/bash

# Function to encrypt text
encrypt_text() {
  local text="$1"
  local password="$2"
  openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -pass "pass:$password" <<< "$text" | base64
}

# Function to decrypt base64-encoded encrypted text
decrypt_text() {
  local encrypted_text="$1"
  local password="$2"
  echo "$encrypted_text" | base64 -d | openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter 100000 -pass "pass:$password"
}

# Helper function to encrypt and save a secret to a file
encrypt_and_store_secret() {
  local secret_name="$1"
  local secret_value="$2"
  local password_file="/etc/datadog-agent/secret_password"

  if [[ ! -f "$password_file" ]]; then
    echo "Password file not found: $password_file" >&2
    return 1
  fi

  local password
  password=$(<"$password_file")

  encrypted=$(encrypt_text "$secret_value" "$password")
  if [[ -n "$encrypted" ]]; then
    echo -n "$encrypted" > "$secret_name"
    chmod 600 "$secret_name"
    chown dd-agent:dd-agent "$secret_name"
    echo "Secret encrypted and saved to: $secret_name"
  else
    echo "Encryption failed for $secret_name" >&2
    return 1
  fi
}

# Function used by Datadog secret_backend_command
datadog_secret_backend() {
  local password_file="/etc/datadog-agent/secret_password"
  local password

  if [[ ! -f "$password_file" ]]; then
    echo "Missing password file" >&2
    exit 1
  fi

  password=$(<"$password_file")

  # Read JSON input from stdin
  read -r input_json

  # Extract the list of secrets using jq
  secret_names=$(echo "$input_json" | jq -r '.secrets[]')

  # Prepare output JSON
  output="{"

  for secret in $secret_names; do
    secret_file="$secret"
    if [[ -f "$secret_file" ]]; then
      encrypted_value=$(<"$secret_file")
      if decrypted_value=$(decrypt_text "$encrypted_value" "$password" 2>/dev/null); then
        output+="\"$secret\": {\"value\": \"${decrypted_value//\"/\\\"}\", \"error\": null},"
      else
        output+="\"$secret\": {\"value\": null, \"error\": \"decryption failed\"},"
      fi
    else
      output+="\"$secret\": {\"value\": null, \"error\": \"file not found\"},"
    fi
  done

  # Trim trailing comma and close JSON
  output="${output%,}}"
  echo "$output"
}

# If called with --secret-backend (Datadog mode)
if [[ "$1" == "--secret-backend" ]]; then
  datadog_secret_backend
  exit 0
fi

# Command-line interface
if [[ "$1" == "encrypt_and_store_secret" && $# -eq 3 ]]; then
  encrypt_and_store_secret "$2" "$3"
  exit $?
fi

# Legacy encrypt/decrypt usage
if [[ $# -ne 3 ]]; then
  echo "Usage:"
  echo "  $0 encrypt <text> <password>"
  echo "  $0 decrypt <base64_encrypted_text> <password>"
  echo "  $0 encrypt_and_store_secret <secret_name> <secret_value>"
  echo "  $0 --secret-backend"
  exit 1
fi

action="$1"
text="$2"
password="$3"

case "$action" in
  encrypt)
    encrypted_text=$(encrypt_text "$text" "$password")
    echo "Encrypted text: $encrypted_text"
    ;;
  decrypt)
    decrypted_text=$(decrypt_text "$text" "$password")
    echo "Decrypted text: $decrypted_text"
    ;;
  *)
    echo "Invalid action: $action"
    exit 1
    ;;
esac
