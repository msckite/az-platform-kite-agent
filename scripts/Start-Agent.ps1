<#
.SYNOPSIS
    Starts Claude Code as the MSCKite Agent GitHub App instead of as a human.

.DESCRIPTION
    Gets a short-lived installation token (Get-AgentToken.ps1), sets it as GH_TOKEN for this process and the child process only,
    makes git use it, sets the bot as the git author, proves that the token is not a user token, and starts claude.
    The script never falls back to a personal login: when no token can be created, it stops.
    The previous environment is restored when claude exits.

    The token expires after one hour. Restart the script for a longer session.

.PARAMETER ClientId
    Client ID of the GitHub App. Defaults to $env:KITE_AGENT_CLIENT_ID.

.PARAMETER Owner
    Owner of the repository the token is limited to.

.PARAMETER Repository
    Repository the token is limited to.

.PARAMETER BotLogin
    Login of the App's bot, shown on the App's public page. Used as the git author.

.PARAMETER ClaudePath
    Path of a claude executable, for when claude is not on the PATH. Defaults to $env:KITE_AGENT_CLAUDE_PATH, then to ~/.local/bin/claude.exe (the default install location), then to claude on the PATH.

.PARAMETER ClaudeArguments
    Extra arguments for claude.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ClientId = $env:KITE_AGENT_CLIENT_ID,
    [string]$Owner = 'msckite',
    [string]$Repository = 'az-platform-kite-agent',
    [string]$BotLogin = 'msckite-agent[bot]',
    [string]$ClaudePath = $env:KITE_AGENT_CLAUDE_PATH,
    [string[]]$ClaudeArguments = @()
)

$ErrorActionPreference = 'Stop'

# A variable saved with SetEnvironmentVariable(..., 'User') is not visible to terminals that were already open.
if ([string]::IsNullOrWhiteSpace($ClientId)) {
    $ClientId = [Environment]::GetEnvironmentVariable('KITE_AGENT_CLIENT_ID', 'User')
}

$steps = @(
    'Get an installation token limited to {0}/{1} from the secret vault key' -f $Owner, $Repository
    'Set GH_TOKEN and the git identity for this process only'
    'Check that the token is not a user token (gh api user must fail)'
    'Start claude'
)

if ($WhatIfPreference) {
    $steps | ForEach-Object { Write-Information "What if: $_" -InformationAction Continue }
    return
}

foreach ($tool in 'gh', 'git') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool was not found on the PATH."
    }
}

if ($ClaudePath) {
    if (-not (Test-Path -LiteralPath $ClaudePath -PathType Leaf)) {
        throw "ClaudePath '$ClaudePath' does not exist."
    }
    $claude = (Resolve-Path -LiteralPath $ClaudePath).Path
} else {
    # Default install location of the Claude Code CLI on Windows; a claude on the PATH is used otherwise.
    $defaultPath = [IO.Path]::Combine($HOME, '.local', 'bin', 'claude.exe')
    $command = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (Test-Path -LiteralPath $defaultPath -PathType Leaf) {
        $claude = $defaultPath
    } elseif ($command) {
        $claude = $command.Source
    } else {
        throw "claude was not found at '$defaultPath' or on the PATH. Install the Claude Code CLI, or pass -ClaudePath (or set KITE_AGENT_CLAUDE_PATH) to a claude executable."
    }
}

$token = & (Join-Path -Path $PSScriptRoot -ChildPath 'Get-AgentToken.ps1') -ClientId $ClientId -Owner $Owner -Repository $Repository
if (-not $token -or [string]::IsNullOrWhiteSpace($token.Token)) {
    throw 'No installation token was created. The agent does not start without one.'
}

$names = 'GH_TOKEN', 'GITHUB_TOKEN', 'GH_ENTERPRISE_TOKEN', 'GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_COMMITTER_NAME',
'GIT_COMMITTER_EMAIL', 'GIT_CONFIG_COUNT', 'GIT_CONFIG_KEY_0', 'GIT_CONFIG_VALUE_0', 'GIT_CONFIG_KEY_1', 'GIT_CONFIG_VALUE_1'
$previous = @{}
foreach ($name in $names) {
    $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

try {
    $env:GH_TOKEN = $token.Token
    Remove-Item Env:GITHUB_TOKEN, Env:GH_ENTERPRISE_TOKEN -ErrorAction SilentlyContinue

    # An installation token is not a user: the user endpoint must be refused. If it answers, this is a personal token.
    $null = gh api user 2>&1
    if ($LASTEXITCODE -eq 0) {
        throw 'gh api user succeeded, so the token is a user token. The agent must not run with a user identity.'
    }

    $botId = gh api "users/$($BotLogin -replace '\[bot\]', '%5Bbot%5D')" --jq '.id' 2>$null
    $email = if ($botId) { "$botId+$BotLogin@users.noreply.github.com" } else { "$BotLogin@users.noreply.github.com" }
    $env:GIT_AUTHOR_NAME = $env:GIT_COMMITTER_NAME = $BotLogin
    $env:GIT_AUTHOR_EMAIL = $env:GIT_COMMITTER_EMAIL = $email

    # Make git push with the token, whatever the user's own git configuration says.
    $env:GIT_CONFIG_COUNT = '2'
    $env:GIT_CONFIG_KEY_0 = 'credential.https://github.com.helper'
    $env:GIT_CONFIG_VALUE_0 = ''
    $env:GIT_CONFIG_KEY_1 = 'credential.https://github.com.helper'
    $env:GIT_CONFIG_VALUE_1 = '!gh auth git-credential'

    Write-Information "Agent identity: $BotLogin. Token expires at $($token.ExpiresAt.ToString('HH:mm')) UTC; restart before then." -InformationAction Continue
    & $claude @ClaudeArguments
} finally {
    foreach ($name in $names) {
        [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
    }
}
