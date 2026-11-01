<!-- omit from toc -->
# Agent identity

An agent has its own identity, so you can always see what a human wrote and what an agent wrote, and so that an agent never
carries a human's privileges.

<!-- omit from toc -->
## Table of Contents

- [Identity](#identity)
- [What the agent may do](#what-the-agent-may-do)
- [What the agent may not do](#what-the-agent-may-not-do)
- [Running as the bot](#running-as-the-bot)
- [Commits and pull requests](#commits-and-pull-requests)
- [Several agents](#several-agents)

## Identity

| Item | Value |
| ---- | ----- |
| Account type | GitHub App owned by the `msckite` organization, see [github-app-setup.md](./github-app-setup.md) |
| Name | `MSCKite™ Agent` |
| Login | `msckite-agent[bot]` (slug `msckite-agent`, see `https://github.com/apps/msckite-agent`) |
| Avatar | Different from every human's avatar |
| Role in repositories | Installed on selected repositories only, with the permissions in the setup guide |
| Branches | Can only write to `agent/**`, enforced by [rulesets](./rulesets.md) |

A GitHub App bot has no profile page, so hovering over `msckite-agent[bot]` shows "Failed to fetch hovercard content: 404". That
is normal; the bot's page is [github.com/apps/msckite-agent](https://github.com/apps/msckite-agent).

## What the agent may do

- Read the repository, issues and pull requests.
- Research and propose a plan in chat.
- Create an issue from the issue form with the approved plan.
- Set status labels by key: `plan-proposed`, `in-progress`, `in-pr`.
- Create branches named `agent/<issue-number>-<slug>`, commit, push and open pull requests.
- Offer a smoke test with every change.

## What the agent may not do

- Set `approved`, unless a human explicitly asks for it in the current chat.
- Push to any branch other than `agent/**`.
- Merge or approve pull requests, delete branches it did not create, or create releases and tags.
- Change rulesets, settings, secrets or the agent's own permissions.
- Act with a human's credentials or tokens.

Anything that is hard to reverse, or visible to others, requires an explicit yes in the chat first.

## Running as the bot

Start the agent with [Start-Agent.ps1](../../scripts/Start-Agent.ps1), not with `claude` directly. It gives the agent a
short-lived installation token (one repository, one hour) and sets the bot as the git author, so the agent never uses a human
login. See [github-app-setup.md](./github-app-setup.md#let-claude-code-use-the-app).

The Claude desktop app can run as the bot too, when it is started through the script with `-ClaudePath` (quit it completely first),
see the note in the setup guide. An approval by the bot does not unblock a pull request: the ruleset also requires the commit status
`human-approval`, which needs an approval of a human with write access, see [rulesets.md](./rulesets.md).

Once the agent runs as the bot, enable the approval guard by setting the repository variable `APPROVAL_GUARD_ENABLED` to `true`:

```powershell
gh variable set APPROVAL_GUARD_ENABLED --body true --repo msckite/az-platform-kite-agent
```

## Commits and pull requests

Every agent commit ends with a `Co-Authored-By` trailer, so the avatar and the history show who did what:

```text
Co-Authored-By: Claude <noreply@anthropic.com>
```

Use the exact trailer that your Claude Code version proposes in its commit instructions. Pull request descriptions list the
issue they close and the smoke test, see [process.md](./process.md).

## Several agents

The same rules apply to every agent you add, for example GitHub Copilot later. Give each its own identity, install it only on
selected repositories and keep it off the bypass lists. The rules in [AGENTS.md](../../AGENTS.md) are the shared contract.
