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
- [Install the App](#install-the-app)
- [Keep the private key safe](#keep-the-private-key-safe)
- [Let Claude Code use the App](#let-claude-code-use-the-app)
- [Remove personal credentials from the agent](#remove-personal-credentials-from-the-agent)
- [Smoke test](#smoke-test)

## Create the App

1. Open **Organization settings** > **Developer settings** > **GitHub Apps** > **New GitHub App** for `msckite`.
2. Name it, for example `msckite-kite-agent`. The name becomes the bot's login, `msckite-kite-agent[bot]`.
3. Homepage URL: the repository URL.
4. Disable **Webhook** (Active). The agent pulls, GitHub does not push events to it.
5. Under **Where can this GitHub App be installed?** choose **Only on this account**.
6. Select **Create GitHub App**. The creation form has no logo field.
7. Once the App exists, its settings page shows **Display information** with an **Upload a logo...** button. Upload a logo that
   is clearly different from your own avatar, so you can see who wrote what. The logo appears as the bot's avatar.

## Permissions

Grant the least privilege that the process needs, as **Repository permissions**:

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

## Install the App

1. Open the App settings > **Install App** > `msckite`.
2. Choose **Only select repositories** and select `az-platform-kite-agent`. Add other repositories one by one.

Never choose **All repositories**.

## Keep the private key safe

1. In the App settings > **Private keys** > **Generate a private key**. GitHub downloads a `.pem` file once.
2. Store it **outside every repository**, for example in a folder only your user can read, or in a secret store such as the
   Windows Credential Manager through the PowerShell SecretManagement module. Do not put it in a project folder,
   and do not paste it into a chat or an issue.
3. Rotate the key when a person with access leaves, or when you suspect it leaked. Delete the old key in the App settings.

`.gitignore` already blocks `*.pem` and `*.key`, as a second line of defence.

## Let Claude Code use the App

A GitHub App authenticates in two steps: sign a short-lived JWT with the private key, then exchange it for an **installation
token** that expires after one hour. The `gh` CLI uses the token through `GH_TOKEN`.

_(unverified)_ The planned approach is a small PowerShell script in this repository that:

1. Reads the App id, the installation id and the key location from environment variables or the secret store.
2. Creates the JWT and requests an installation token from `POST /app/installations/{id}/access_tokens`.
3. Sets `GH_TOKEN` in the current process only, not permanently, then starts `claude`.

Until that script exists, the agent runs with your own `gh` login, and you review every push, issue and pull request. That is
the reason the rulesets protect `main` first.

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
