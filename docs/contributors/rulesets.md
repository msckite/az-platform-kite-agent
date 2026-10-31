<!-- omit from toc -->
# Rulesets

Rulesets are how GitHub enforces the [human-in-the-loop process](./process.md). The agent has its own identity (see
[agent-identity.md](./agent-identity.md)) and is **not** on any bypass list, so it can only do what the rulesets allow.

<!-- omit from toc -->
## Table of Contents

- [The two rulesets](#the-two-rulesets)
- [Why the agent needs no bypass](#why-the-agent-needs-no-bypass)
- [GitHub Team plan notes](#github-team-plan-notes)
- [Create the rulesets](#create-the-rulesets)
- [Smoke test](#smoke-test)

## The two rulesets

| Ruleset | Applies to | Rules | Bypass |
| ------- | ---------- | ----- | ------ |
| `protect-non-agent-branches` | All branches except `agent/**` | Pull request required, 1 approval, stale reviews dismissed on push, review threads resolved, **squash merge only** | Repository admins, through a pull request only |
| `protect-default-branch` | The default branch (`main`) | Block deletion, block force-push | None |

The definitions are in [templates/github/rulesets](../../templates/github/rulesets):

- [protect-non-agent-branches.json](../../templates/github/rulesets/protect-non-agent-branches.json)
- [protect-default-branch.json](../../templates/github/rulesets/protect-default-branch.json)

## Why the agent needs no bypass

- Every branch except `agent/**` requires a pull request, so the agent cannot push to `main` or any other protected branch.
- The agent can push to `agent/**`, which is where it works.
- The agent has no permission to merge or approve, and a human must approve, so **nobody can merge their own work unreviewed**
  (except an admin who deliberately uses the bypass).
- Pull requests opened with the default `GITHUB_TOKEN` do not trigger other workflows. Use the GitHub App identity for the agent
  instead, see [github-app-setup.md](./github-app-setup.md).

> [!NOTE]
> A single human cannot approve their own pull request. While a human opens the pull requests (before the GitHub App exists),
> the admin bypass through a pull request is used. Once the bot opens the pull requests, the human approves them normally.

## GitHub Team plan notes

- Rulesets are available on the **Team** plan for a single repository. Rulesets that span an organization require **Enterprise**,
  so apply these two to every repository.
- GitHub shows only **Active** and **Disabled** enforcement. There is no evaluate mode to dry-run a ruleset.
- Check the current plan limits in the [GitHub documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
  before relying on a feature that is not used here, such as push rulesets.

## Create the rulesets

Run these from the repository root, replacing the owner and repository. They need admin permission on the repository.

```powershell
$repo = 'msckite/az-platform-kite-agent'
gh api -X POST "repos/$repo/rulesets" --input ./templates/github/rulesets/protect-non-agent-branches.json
gh api -X POST "repos/$repo/rulesets" --input ./templates/github/rulesets/protect-default-branch.json
```

To change a ruleset, send the whole definition with `PUT repos/$repo/rulesets/<id>`. List the ids with
`gh api repos/$repo/rulesets --jq '.[] | "\(.id) \(.name)"'`.

> [!IMPORTANT]
> The bypass actor in `protect-non-agent-branches.json` is the repository admin role (`actor_id` 5). Do not add the GitHub App to
> any bypass list.

## Smoke test

After creating the rulesets, prove them with a throwaway clone:

```powershell
git switch -c scratch/ruleset-test
git commit --allow-empty -m "test: Ruleset check"
git push origin scratch/ruleset-test   # expect: rejected, pull request required
git push origin HEAD:agent/ruleset-test # expect: accepted
git push origin --delete agent/ruleset-test
```

The admin bypass works through a pull request only, so the first push is rejected for admins as well. Repeat the test as the bot
once the GitHub App exists. The last command cleans up the test branch.
