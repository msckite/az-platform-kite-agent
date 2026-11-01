<!-- omit from toc -->
# Azure Platform Kite Agent

By **MSCKite™**  
_Lighter Work. Higher Impact._

> [!IMPORTANT]
> This repository is under construction and intended primarily for personal use.

## What's this repo about?

Two things in one repository:

1. **The Kite Agent**: a Claude Code plugin that knows the
   [`MSCKite.Azure.Platform`](https://www.powershellgallery.com/packages/MSCKite.Azure.Platform) PowerShell module, its goals,
   principles and governance, so people can start their own platform projects smoothly. _(planned)_
2. **A human-in-the-loop way of working** with coding agents (Claude Code first, GitHub Copilot later), built on
   GitHub issues, labels, branches and pull requests.

> **AI supports, humans decide.** Agents research, propose and execute; humans approve every plan and every merge.

See [AGENTS.md](./AGENTS.md) for the rules agents follow here.

## Status

| Area | State |
| ---- | ----- |
| Repository foundation | Done |
| Label set with keys | Done |
| Rulesets | Done, see [rulesets](./docs/contributors/rulesets.md) |
| Process, GitHub App and agent identity guides | Done, see [process](./docs/contributors/process.md), [GitHub App setup](./docs/contributors/github-app-setup.md) and [agent identity](./docs/contributors/agent-identity.md) |
| Label status workflows and approval guard | Done, see [process](./docs/contributors/process.md#automation) |
| Agent token script (run as the GitHub App) | Done, see [GitHub App setup](./docs/contributors/github-app-setup.md#let-claude-code-use-the-app) |
| Issue form and pull request template | Done, see [process](./docs/contributors/process.md#the-issue-is-the-source-of-truth) |
| Label sync script | Done, see [process](./docs/contributors/process.md#sync-the-labels) |
| Kite Agent plugin | Planned |

## License

See [LICENSE.md](./LICENSE.md).
