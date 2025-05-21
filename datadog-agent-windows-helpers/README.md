# 🛠️ Guide: Secure Secret Management for Datadog Agent on Windows

This guide helps you set up secret management for the Datadog Agent on Windows using the official `datadog-secret-backend` tool.

Reference source: https://github.com/DataDog/datadog-secret-backend

## 🔐 1. Installation

### Download and Extract the Secret Backend Tool

```powershell
# Create directory for the secret backend
mkdir 'C:\Program Files\datadog-secret-backend\'

# Download the appropriate version (amd64 for 64-bit systems)
Invoke-WebRequest https://github.com/DataDog/datadog-secret-backend/releases/latest/download/datadog-secret-backend-windows-amd64.zip -OutFile 'C:\Program Files\datadog-secret-backend\datadog-secret-backend-windows-amd64.zip'

# Extract the zip file
Expand-Archive -LiteralPath 'C:\Program Files\datadog-secret-backend\datadog-secret-backend-windows-amd64.zip' -DestinationPath 'C:\Program Files\datadog-secret-backend\'

# Clean up the zip file
Remove-Item 'C:\Program Files\datadog-secret-backend\datadog-secret-backend-windows-amd64.zip'
```

> ⚠️ **Note:** For 32-bit systems, use `datadog-secret-backend-windows-386.zip` instead.

## 🔒 2. Configure Security Permissions

The Datadog Agent expects the executable to be accessible only to the `ddagentuser` on Windows:

1. Right-click on `datadog-secret-backend.exe` and select **Properties**
2. Click on the **Security** tab
3. Click **Edit** > **Advanced**
4. Click **Disable inheritance** and choose **Remove all inherited permissions**
5. Click **Add** > **Select a principal**
6. Enter `ddagentuser` and click **Check Names** > **OK**
7. Select **Full control** under permissions
8. Click **OK** > **Apply** > **OK**

## ⚙️ 3. Configure the Secret Backend

### Create the Configuration File

Create a new file at `C:\Program Files\datadog-secret-backend\datadog-secret-backend.yaml`:

```yaml
backends:
  agent_secret:
    backend_type: file.yaml
    file_path: C:\ProgramData\Datadog\secrets.yaml
```

### Create the Secrets File

Create a new file at `C:\ProgramData\Datadog\secrets.yaml` with your secrets:

```yaml
api_key: "MY_API_KEY"
hostalias: "secretalias"
db_password: "MyDatabasePassword"
api_token: "MySuperSecretAPIToken"
```

> 🔐 **Security Note:** Make sure to set appropriate permissions on this file to limit access!

## 🧩 4. Configure the Datadog Agent

Edit the Datadog Agent configuration file at `C:\ProgramData\Datadog\datadog.yaml`:

```yaml
# Add the secret_backend_command 
secret_backend_command: C:\Program Files\datadog-secret-backend\datadog-secret-backend.exe

# Test with host aliases (optional)
host_aliases:
  - ENC[agent_secret:hostalias]
```

## 🔄 5. Restart the Datadog Agent

```powershell
# Restart the Datadog Agent service
Restart-Service -Name datadogagent
```

## 🧪 6. Test and Verify Your Setup

### Check the Agent Configuration

```powershell
# Check if the agent can access the secrets
& 'C:\Program Files\Datadog\Datadog Agent\bin\agent.exe' secret

# Expected output should show successful decryption of secrets
```

## 📝 Using Encrypted Secrets in Configurations

You can now use your encrypted secrets in Datadog configuration files with the `ENC[]` syntax:

```yaml
# Example PostgreSQL integration using encrypted secrets
# C:\ProgramData\Datadog\conf.d\postgres.d\conf.yaml
init_config:
instances:
  - host: localhost
    port: 5432
    username: datadog
    password: ENC[agent_secret:db_password]
```

### Verify Secret Injection 

```powershell
# Check if the agent can read configurations with secrets
& 'C:\Program Files\Datadog\Datadog Agent\bin\agent.exe' configcheck

# Secrets should appear as <redacted> in the output
```

## 🔧 Troubleshooting

- **Permissions Issues**: Ensure `ddagentuser` has full access to both the executable and config files
- **Command Not Found**: Verify the path in `secret_backend_command` is correct and accessible
- **Secret Not Found**: Check the backend configuration and that your secret exists in the secrets.yaml file
- **Check Logs**: Review `C:\ProgramData\Datadog\logs\agent.log` for errors related to the secret backend

---

This setup provides a secure way to manage secrets for your Datadog Agent on Windows. The secrets are stored locally and only accessible to the Datadog Agent process.