# 🔐 Datadog Agent Encrypted Secret Backend

A secure, lightweight solution for managing encrypted secrets with the Datadog Agent across different platforms.

## Overview

This project provides scripts and guides to implement a local encrypted secret backend for Datadog Agent. It enables:

- 🛡️ **Simple and Secure Secret Storage**: Encrypt sensitive information locally
- 🧰 **Cross-Platform**: Support for both Linux and Windows environments
- 🔄 **Integration**: Works with Datadog Agent's `secret_backend_command` feature
- 🛠️ **CLI Tools**: Easy management of secrets through command-line utilities

## Quick Start

Choose your platform guide:

- [📝 Linux Implementation Guide](guide_linux.md)
- [📝 Windows Implementation Guide](guide_windows.md)

## How It Works

The secret backend implements a simple yet secure process:

1. A master password is stored in a protected file
2. Secrets are encrypted with this master password and stored as individual files
3. When Datadog Agent needs a secret, it calls the backend script
4. The script decrypts requested secrets and returns them in the format expected by the Agent

## Security Considerations

- All encrypted files and password stores use proper permissions
- Credentials are never logged or displayed after input
- Scripts handle sensitive data in memory securely

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.