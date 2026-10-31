<!-- omit from toc -->
# GitHub App setup (agent identity)

The agent must not work with your identity and all your privileges. It gets its own identity: a **GitHub App** owned by the
`msckite` organization. A GitHub App has its own name and avatar, needs no paid seat on the Team plan, uses short-lived tokens and
only has the permissions you grant.

> [!NOTE]
> Unverified: this guide was written before the App existed. Steps marked _(unverified)_ must be confirmed when someone follows
> them for the first time, and corrected here.

<!-- omit from toc -->
## Table of Contents

- [Create the App](#create-the-app)
- [Permissions](#permissions)
- [Keep the private key safe](#keep-the-private-key-safe)
- [Restrict who manages the App](#restrict-who-manages-the-app)
- [Install the App](#install-the-app)
- [Let Claude Code use the App](#let-claude-code-use-the-app)
- [Remove personal credentials from the agent](#remove-personal-credentials-from-the-agent)
- [Smoke test](#smoke-test)

## Create the App

1. Open **Organization settings** > **Developer settings** > **GitHub Apps** > **New GitHub App** for `msckite`.
2. Name it, for example `MSCKite™ Agent`. GitHub derives the bot's login from the name as a URL-safe slug followed by `[bot]`.
   The slug is shown on the App's **Public page**; use that login in rulesets and documentation.
3. Homepage URL: the repository URL.
4. Disable **Webhook** (Active). The agent pulls, GitHub does not push events to it.
5. Under **Where can this GitHub App be installed?** choose **Only on this account**.
6. Select **Create GitHub App**. The creation form has no logo field.
7. Once the App exists, its settings page has this menu. The next steps refer to these pages:

   | Page | Used for |
   | ---- | -------- |
   | **General** | Display information, the logo (step 8) and the **Webhook** setting (step 4, check it is off) |
   | **Permissions & events** | [Permissions](#permissions) |
   | **Credentials** | [Private key](#keep-the-private-key-safe) |
   | **Install App** | [Installation](#install-the-app) |
   | **App managers** | [Who may manage the App](#restrict-who-manages-the-app) |

   The pages **Optional features**, **Advanced** and **Public page** need no changes.

8. On **General**, **Display information** has an **Upload a logo...** button. Upload a logo that is clearly different from
   your own avatar, so you can see who wrote what. The logo appears as the bot's avatar.

## Permissions

Open **Permissions & events** and grant the least privilege that the process needs, as **Repository permissions**:

| Permission | Access | Why |
| ---------- | ------ | --- |
| Metadata | Read | Required by GitHub for every App. |
| Contents | Read and write | Push commits to `agent/**` branches. |
| Pull requests | Read and write | Open and update pull requests. |
| Issues | Read and write | Create issues and set labels. |

Leave **Organization permissions**, **Account permissions** and **Enterprise permissions** on their default, **No access**.
Only the four repository permissions above are needed.

Do **not** grant Administration, Workflows, Actions or Environments. Without Administration the App cannot change rulesets, and
without a bypass entry it cannot push to protected branches. It also cannot approve or merge its own pull request, because a
human approval is required.

> [!IMPORTANT]
> Setting the `approved` label is a human gate, but GitHub cannot restrict a single label to humans through permissions alone.
> The agent rule in [AGENTS.md](../../AGENTS.md) forbids it and a workflow reverts it (planned). Treat both as controls.

## Keep the private key safe

1. In the App settings > **Credentials** > **Key pairs** tab, generate a key pair. GitHub downloads a `.pem` file once. The key
   cannot be created on the creation form, only after the App exists.
   Ignore the **Client secrets** tab: client secrets are for user sign-in (OAuth), which the agent does not use.
2. Store it **outside every repository**, in a PowerShell secret vault, see [secret-management.md](./secret-management.md).
   Do not put it in a project folder, and do not paste it into a chat or an issue.
3. Rotate the key when a person with access leaves, or when you suspect it leaked. Delete the old key under **Credentials**.

`.gitignore` already blocks `*.pem` and `*.key`, as a second line of defence.

## Restrict who manages the App

Under **App managers**, keep the list as short as possible. A manager can change the App's permissions and generate keys, so
only trusted humans belong there. The agent is never an App manager.

## Install the App

Do this last, after the permissions are set and the private key is generated, because the installation redirects you away from
the App settings.

1. Open the App settings > **Install App**, and select **Install** next to `msckite`.
2. Choose **Only select repositories** and select `az-platform-kite-agent`. Add other repositories one by one.
3. After you select **Install**, GitHub redirects you to the installation page, not back to the App settings. To return to the
   App settings, open **Organization settings** > **Developer settings** > **GitHub Apps** and select **Edit** next to the App.

Never choose **All repositories**.

## Let Claude Code use the App

A GitHub App authenticates in two steps: sign a short-lived JWT with the private key, then exchange it for an **installation
token** that expires after one hour. The `gh` CLI uses the token through `GH_TOKEN`.

Two scripts in [scripts](../../scripts) do this for you:

- [Get-AgentToken.ps1](../../scripts/Get-AgentToken.ps1) reads the private key from the vault (see
  [secret-management.md](./secret-management.md)), signs the JWT, looks up the installation of the repository and requests an
  installation token that is limited to that one repository. The key and the token stay in memory.
- [Start-Agent.ps1](../../scripts/Start-Agent.ps1) sets `GH_TOKEN` for the process only, makes git push with the token, sets the
  bot as the git author, checks that `gh api user` fails (an installation token is not a user), starts `claude`, and restores
  your environment when `claude` exits. It never falls back to your own login: without a token it stops.

Set the **Client ID** (shown on **General**; an identifier, not a secret) once in your own terminal profile:

```powershell
[Environment]::SetEnvironmentVariable('KITE_AGENT_CLIENT_ID', '<client-id>', 'User')
```

A terminal that was already open does not see the new value, but the scripts also read the saved user-level value, so the
restart is not needed. Without a Client ID they stop.

Then start the agent from the repository, instead of starting `claude` directly:

```powershell
./scripts/Start-Agent.ps1            # starts claude as the bot
./scripts/Start-Agent.ps1 -WhatIf    # shows the steps, creates no token
```

The script needs the Claude Code CLI. It uses, in this order: `-ClaudePath`, `KITE_AGENT_CLAUDE_PATH`, the default install
location `~/.local/bin/claude.exe`, then `claude` on your PATH. The script stops, and does not fall back to anything else, when it
cannot find an executable.

> [!NOTE]
> The script starts a CLI session in your terminal and gives that process the token. A session in the Claude desktop app runs in
> the app's own process, so the script cannot change its identity. Whether the desktop app can act as the bot, for example by
> starting the app from a process that holds the token, is untested.

The token expires after one hour. Restart the script when it runs out; the script prints the expiry time. A script run without
the App (for example while the vault is not set up) fails instead of using your login.

> [!NOTE]
> Verified offline only: the JWT signature (RS256, at most 10 minutes), the `-WhatIf` run and the scripts' static analysis, with
> `Invoke-Pester ./scripts/tests`. Unverified until someone runs it with the real key: the token exchange, the bot's git author
> and the push through the credential helper. Correct this section after the first run.

In workflows, use the `actions/create-github-app-token` action with the App id and key stored as a repository variable and secret.

## Remove personal credentials from the agent

The agent must not reuse your identity through another route:

- Remove or disable integrations that act as you, for example a GitHub connector in an AI tool that uses your account.
- Start Claude Code from a terminal where `GH_TOKEN` is the installation token. Do not sign `gh` in with your own account in
  that terminal.
- Keep Claude Code on permission prompts, so you approve each command.

## Smoke test

With the installation token as `GH_TOKEN`:

```powershell
gh api user                                   # expect: error, an installation token is not a user
gh api repos/msckite/az-platform-kite-agent --jq .full_name    # expect: msckite/az-platform-kite-agent
git push origin HEAD:agent/app-test           # expect: accepted
git push origin HEAD:main                     # expect: rejected, pull request required
gh pr merge <pull-request-number> --squash    # expect: rejected, the App cannot merge
git push origin --delete agent/app-test       # clean up
```
