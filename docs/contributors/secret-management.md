<!-- omit from toc -->
# Store secrets with SecretManagement

Secrets such as the GitHub App private key never belong in a repository, a chat or an issue. On a developer machine, store
them in a PowerShell vault with the `Microsoft.PowerShell.SecretManagement` and `Microsoft.PowerShell.SecretStore` modules.

<!-- omit from toc -->
## Table of Contents

- [Install the modules](#install-the-modules)
- [Register and configure the vault](#register-and-configure-the-vault)
- [Store the GitHub App private key](#store-the-github-app-private-key)
- [Read the key back](#read-the-key-back)
- [Check the vault](#check-the-vault)
- [If a key is lost or leaked](#if-a-key-is-lost-or-leaked)

## Install the modules

Run these once, in your own PowerShell terminal. Use `-Scope AllUsers` in an elevated terminal, or `-Scope CurrentUser` without
elevation.

```powershell
Install-Module Microsoft.PowerShell.SecretManagement -Scope AllUsers -Force
Install-Module Microsoft.PowerShell.SecretStore -Scope AllUsers -Force
```

```powershell
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser -Force
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser -Force
```

## Register and configure the vault

Run these once:

```powershell
Register-SecretVault -Name KiteAgent -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
Set-SecretStoreConfiguration -Authentication Password -Interaction Prompt
```

`-Authentication Password` makes the store ask for a vault password, and that password is the real protection. With
`-Authentication None` anything that runs as your user can read the secrets. Use a password.

## Store the GitHub App private key

Run this in your own terminal, not through an agent, so the key never enters a chat. Replace the file name with the `.pem` file
that GitHub downloaded, see [github-app-setup.md](./github-app-setup.md).

```powershell
$pem = Get-Content -Raw "$HOME\Downloads\<downloaded-file>.pem"
Set-Secret -Name KiteAgentAppKey -Secret $pem -Vault KiteAgent
Remove-Item "$HOME\Downloads\<downloaded-file>.pem"
Remove-Variable pem
```

`Remove-Item` skips the Recycle Bin. The vault should hold the only copy of the key.

## Read the key back

```powershell
$pem = Get-Secret -Name KiteAgentAppKey -Vault KiteAgent -AsPlainText
```

Keep the value in memory only. Never write it to a file, a log or a command line.

## Check the vault

```powershell
Get-SecretInfo -Vault KiteAgent
# Expect: KiteAgentAppKey is listed with type String
```

## If a key is lost or leaked

Delete the key on the App's **Credentials** > **Key pairs** tab, generate a new key pair and store it again with the steps above.
Remove the old secret from the vault with `Remove-Secret -Name KiteAgentAppKey -Vault KiteAgent` before you store the new one.
