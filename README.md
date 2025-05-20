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
read -s -p "Enter encryption password: " PASSWORD
echo "$PASSWORD" > /etc/datadog-agent/secret_password
unset PASSWORD

# Restrict file permissions
chmod 600 /etc/datadog-agent/secret_password
chown dd-agent:dd-agent /etc/datadog-agent/secret_password
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
sudo /etc/datadog-agent/datadog_helpers.sh encrypt_and_store_secret my_db_password "MyDatabasePassword"
sudo /etc/datadog-agent/datadog_helpers.sh encrypt_and_store_secret api_token "MySuperSecretAPIToken"
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
secret_backend_command: 
  - /etc/datadog-agent/datadog_helpers.sh
  - --secret-backend
```

Then restart the Agent:

```bash
sudo systemctl restart datadog-agent
```

---

### 🧪 5. Test Decryption (Optional)

You can test the backend decryption manually to verify things are working:

```bash
echo '{"version": "1.0", "secrets": ["my_db_password", "api_token"]}' | /etc/datadog-agent/datadog_helpers.sh --secret-backend
```

Expected output:

```json
{
  "my_db_password": {"value": "MyDatabasePassword", "error": null},
  "api_token": {"value": "MySuperSecretAPIToken", "error": null}
}
```

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
