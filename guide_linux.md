# 🛠️ Guide: Secure Secret Management for Datadog Agent (with CLI)

This guide helps you:

* Set up encryption for secrets
* Use Datadog Agent’s `secret_backend_command` feature
* Manage secrets via a CLI using the updated `datadog_helpers.sh` script

---

### 🔐 1. Create the Shared Password File

This password will be used to **encrypt and decrypt all secrets** consistently.

```bash
# Enter a strong password without showing it
sudo /bin/bash -c 'read -s -p "Enter encryption password: " PASSWORD && echo "$PASSWORD" > /etc/datadog-agent/secret_password && unset PASSWORD'

# Restrict file permissions
sudo chmod 600 /etc/datadog-agent/secret_password
sudo chown dd-agent:dd-agent /etc/datadog-agent/secret_password
```

---

### 📜 2. Install the Script

Save the full script (from the previous response) as:

```bash
sudo curl -LJ https://github.com/nuttea/datadog-agent-local-encrypted-secret-backend-command/raw/refs/heads/main/datadog_helpers.sh -o /etc/datadog-agent/datadog_helpers.sh 
```

Paste the script, then:

```bash
sudo chmod 700 /etc/datadog-agent/datadog_helpers.sh
sudo chown dd-agent:dd-agent /etc/datadog-agent/datadog_helpers.sh
```

> ✅ Ensure `jq` is installed:
>
> ```bash
> sudo apt install jq     # Debian/Ubuntu
> sudo yum install jq     # RHEL/CentOS
> ```

---

### 🔏 3. Encrypt and Store Secrets (via CLI)

You can now encrypt secrets and store them with one simple command:

```bash
cd /etc/datadog-agent/
sudo ./datadog_helpers.sh encrypt_and_store_secret my_db_password "MyDatabasePassword"
sudo ./datadog_helpers.sh encrypt_and_store_secret api_token "MySuperSecretAPIToken"
```

This will:

* Encrypt the value using the password file
* Save the encrypted value to files:

  * `/etc/datadog-agent/my_db_password`
  * `/etc/datadog-agent/api_token`
* Restrict file permissions for security

---

### ⚙️ 4. Configure the Datadog Agent

Enable secret management by editing:

```yaml
# /etc/datadog-agent/datadog.yaml
secret_backend_command: /etc/datadog-agent/datadog_helpers.sh
```

Then restart the Agent:

```bash
sudo systemctl restart datadog-agent
```

---

### 🧪 5. Test and Verify Your Setup

#### 5.1 Test Backend Decryption Manually

You can test the backend decryption manually to verify things are working:

```bash
echo '{"version": "1.0", "secrets": ["my_db_password", "api_token"]}' | sudo /etc/datadog-agent/datadog_helpers.sh --secret-backend
```

Expected output:

```json
{
  "my_db_password": {"value": "MyDatabasePassword", "error": null},
  "api_token": {"value": "MySuperSecretAPIToken", "error": null}
}
```

#### 5.2 Test with the Agent's Secret Command

Create a sample PostgreSQL integration configuration using your encrypted secrets:

```bash
# Create the configuration file
sudo tee /etc/datadog-agent/conf.d/postgres.d/conf.yaml > /dev/null << 'EOF'
init_config:
instances:
  - dbm: true
    host: localhost
    port: 5432
    username: datadog
    password: 'ENC[my_db_password]'
EOF

# Set proper permissions
sudo chmod 640 /etc/datadog-agent/conf.d/postgres.d/conf.yaml
sudo chown dd-agent:dd-agent /etc/datadog-agent/conf.d/postgres.d/conf.yaml

# Restart Datadog Agent
sudo service datadog-agent restart
```

The `ENC[secret_name]` syntax tells the Datadog Agent to retrieve and decrypt the specified secret using your secret backend command.

The Agent CLI provides built-in tools to verify your secret backend implementation:

```bash
sudo datadog-agent secret
```

This will show:
- Verification of your executable rights
- List of detected secrets in your configuration
- Any errors in your setup

Example output:
```
=== Checking executable rights ===
Executable path: /etc/datadog-agent/datadog_helpers.sh
Check Rights: OK, the executable has the correct rights

Rights Detail:
file mode: 100700
Owner username: dd-agent
Group name: dd-agent

=== Secrets stats ===
Number of secrets decrypted: 2
Secrets handle decrypted:
- my_db_password: from <config_file>
- api_token: from <config_file>
```

#### 5.3 Verify Secret Injection in Configurations

To see how secrets are actually injected into your configurations:

```bash
sudo -u dd-agent -- datadog-agent configcheck
```

This shows all check configurations with secrets properly injected (but securely obfuscated in the output):

```
=== postgres ===
Source: File Configuration Provider
Instance 1:
host: localhost
port: 5432
password: <obfuscated_password>
~
===
```

#### 5.4 Debug the Command Outside the Agent

If needed, you can debug how the Agent interacts with your script:

```bash
sudo -u dd-agent bash -c "echo '{\"version\": \"1.0\", \"secrets\": [\"my_db_password\", \"api_token\"]}' | /etc/datadog-agent/datadog_helpers.sh"
```

This simulates exactly how the Agent calls the secret backend command.

> 📝 **Note:** The Agent needs to be restarted to pick up changes on configuration files.

---

## 🔐 Security Reminders

* Always restrict file permissions on secret files and scripts:

  ```bash
  chmod 600 /etc/datadog-agent/secret_password
  chmod 600 /etc/datadog-agent/my_db_password
  chmod 600 /etc/datadog-agent/api_token
  chmod 700 /etc/datadog-agent/datadog_helpers.sh
  ```
* Ensure all files are owned by `dd-agent`
* Never expose the password in logs or scripts

---

Let me know if you want to extend this to support a subdirectory for secrets or automatic cleanup.
