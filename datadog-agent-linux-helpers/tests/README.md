# BATS Test Suite for Datadog Helpers

This directory contains BATS (Bash Automated Testing System) tests for the Datadog Helpers scripts.

## Overview

These tests validate the functionality of `datadog_helpers.sh`, ensuring all features work correctly and handle errors gracefully.

## Requirements

- BATS (Bash Automated Testing System): [https://github.com/bats-core/bats-core](https://github.com/bats-core/bats-core)

### Installation

```bash
# Method 1: Clone from GitHub
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local  # May require sudo

# Method 2: Package managers
# Ubuntu/Debian
sudo apt-get install bats
# macOS
brew install bats-core
```

## Running Tests

From the project root directory:

```bash
# Run all tests
bats datadog-agent-linux-helpers/tests/

# Run a specific test file
bats datadog-agent-linux-helpers/tests/test_helpers.bats
```

## Test Structure

- test_helpers.bats: Tests core functionality including encryption/decryption, secret storage, and the Datadog secret backend command

## What's Being Tested

1. **Basic Encryption/Decryption**
   - Encrypt text and verify it can be decrypted correctly

2. **Secret Storage**
   - Store encrypted secrets with proper permissions and verify content

3. **Datadog Secret Backend**
   - Process JSON secret requests from Datadog Agent
   - Handle single and multiple secret requests
   - Return properly formatted responses

4. **Error Handling**
   - Missing password file
   - Invalid JSON input
   - Non-existent secrets
   - Invalid commands

## Test Environment

Tests run in isolated temporary directories to ensure they don't interfere with your actual system or each other.

## Adding New Tests

1. Create new test files with `.bats` extension
2. Follow the pattern in existing tests:
   - Use `setup()` to prepare the environment
   - Use `teardown()` to clean up
   - Use `@test` to define test cases

For examples and documentation, see the [BATS wiki](https://github.com/bats-core/bats-core/wiki).