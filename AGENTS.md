# Agent instructions

This repository builds the **MSCKite Kite Agent**, a Claude Code plugin that helps people use the
`MSCKite.Azure.Platform` PowerShell module, and it is also where we define the default
**human-in-the-loop (HITL)** way of working with coding agents. This file is the single, tool-neutral
source of rules. `CLAUDE.md` and other tool adapters point here.

> [!NOTE]
> This repository is in its foundation phase. The working process is in use, but the Kite Agent plugin is not built yet.

## Principles

- **AI supports, humans decide.** Agents research, propose and execute. Humans approve and merge.
- **The GitHub issue is the single source of truth** for status and decisions. Record every decision there.
- **Least privilege.** Agents act under their own identity (a GitHub App), never with a human's privileges.
- **Everything is in English**: issues, documentation, commit messages and agent output.

## Working process

1. A human asks a question or states a need.
2. The agent researches and proposes a plan in chat. The human adjusts it until it is approved.
3. The agent creates a GitHub issue from the issue form with the approved plan (label key `plan-proposed`).
4. A human sets `approved` on the issue, manually or by asking the agent to do it on their behalf.
5. The agent proposes a branch (`agent/<issue-number>-<slug>`), does the work and reports back.
6. The agent always offers a smoke-test script a human can run to prove the change.
7. The agent opens a pull request that closes the issue. A human reviews and merges it.

Status is tracked with label **keys** (not label titles); see
[templates/github/other/github-labels.jsonc](./templates/github/other/github-labels.jsonc). Workflows set most status labels,
see [docs/contributors/process.md](./docs/contributors/process.md#automation).

After a human reports a merge, the agent cleans up: fast-forward the default branch, delete the local branch, prune remote
references, confirm the remote branch is gone and check that the issue labels match its state (see
[After a merge](./docs/contributors/process.md#after-a-merge)).

## Rules that must not be broken

- Do not push to `main`. Work on a branch and open a pull request.
- Do not merge pull requests, delete branches you did not create, or create releases or tags.
- Do not set the `approved` label on your own initiative. Only on an explicit human request in the current chat.
- Ask before any action that is hard to reverse or visible to others (creating issues, pushing, opening pull requests).
- Never commit secrets, tokens or private keys.

## Conventions

- File format follows [.vscode/settings.json](./.vscode/settings.json): UTF-8 without BOM, LF line endings, four spaces
  in PowerShell, two spaces in JSON, JSONC and YAML.
- `camelCase` keys in JSON files, `PascalCase` for public PowerShell identifiers, approved verbs for commands.
- Commit and pull request titles are Conventional Commits: `<type>: <Capitalized summary>`. Pull requests are squash-merged.
- Agent-created issues use the sections of the agent task form, in that order
  ([.github/ISSUE_TEMPLATE/01-agent-task.yml](./.github/ISSUE_TEMPLATE/01-agent-task.yml)): goal, context, proposed plan,
  risk and impact, smoke test, decision log.
- Smoke tests are written in PowerShell, because that is the default shell of the humans reviewing them. Do not use `grep`,
  `sed` or other Unix tools in them.
- Windows with Git Bash has no Python. Use PowerShell or editor tooling for scripted edits.

## Repository map

- `plugin/` - the Kite Agent Claude Code plugin _(planned)_.
- `templates/` and `schemas/` - starter files consumers copy, such as the label set.
- `.github/` - issue forms, pull request template and workflows.
- `docs/` - contributor and consumer documentation.
