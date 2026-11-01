<#
.SYNOPSIS
    Syncs the label set of a repository safely with Set-GitHubLabels.

.DESCRIPTION
    Wraps Set-GitHubLabels of the MSCKite.Azure.Platform module. By default it is a dry run: it validates the label file,
    compares it with the labels of the repository and prints what would be created, updated and removed.
    With -Apply it runs the sync and then runs it again; the second run must report nothing to change.

    Set-GitHubLabels identifies labels by name. A renamed label therefore becomes a new label and the old one is removed, and its
    issues lose the label. A rename is detected as a label to remove and a label to create with the same color and description
    (remote labels carry no key). The script stops on a likely rename unless -Force is passed.

    Requires the MSCKite.Azure.Platform module and a gh login with permission on the repository. Nothing is installed.

.PARAMETER Owner
    Owner of the repository.

.PARAMETER Repository
    Repository to sync.

.PARAMETER LabelFilePath
    Path of the jsonc label file.

.PARAMETER Apply
    Run the sync. Without it, nothing is changed.

.PARAMETER Force
    Continue when a likely rename is found.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Owner,

    [Parameter(Mandatory)]
    [string]$Repository,

    [string]$LabelFilePath = 'templates/github/other/github-labels.jsonc',

    [switch]$Apply,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function ConvertTo-LabelRecord {
    param($Label)

    [pscustomobject]@{
        Name        = [string]$Label.name
        Color       = ([string]$Label.color).TrimStart('#').ToLowerInvariant()
        Description = [string]$Label.description
    }
}

# Compares the desired labels with the labels of the repository by name, like Set-GitHubLabels does.
function Get-LabelPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Desired,

        [AllowEmptyCollection()]
        [object[]]$Remote = @()
    )

    $remoteByName = @{}
    foreach ($label in $Remote) { $remoteByName[$label.Name] = $label }
    $desiredNames = @{}
    foreach ($label in $Desired) { $desiredNames[$label.Name] = $true }

    $create = @($Desired | Where-Object { -not $remoteByName.ContainsKey($_.Name) })
    $remove = @($Remote | Where-Object { -not $desiredNames.ContainsKey($_.Name) })
    $update = @($Desired | Where-Object {
            $remoteByName.ContainsKey($_.Name) -and (
                $remoteByName[$_.Name].Color -ne $_.Color -or $remoteByName[$_.Name].Description -ne $_.Description)
        })

    $renames = foreach ($new in $create) {
        $old = $remove | Where-Object { $_.Color -eq $new.Color -and $_.Description -eq $new.Description } | Select-Object -First 1
        if ($old) { [pscustomobject]@{ From = $old.Name; To = $new.Name } }
    }

    [pscustomobject]@{
        Create  = $create
        Update  = $update
        Remove  = $remove
        Renames = @($renames)
    }
}

function Invoke-LabelSync {
    [CmdletBinding()]
    param(
        [string]$Owner,
        [string]$Repository,
        [string]$LabelFilePath,
        [switch]$Apply,
        [switch]$Force
    )

    if (-not (Test-Path -LiteralPath $LabelFilePath)) {
        throw "Label file not found: $LabelFilePath"
    }

    if (-not (Get-Module -ListAvailable -Name MSCKite.Azure.Platform)) {
        throw 'Module MSCKite.Azure.Platform is not installed. Install it from the PowerShell Gallery; this script installs nothing.'
    }

    # Validates unique kebab-case keys and the keys that the process needs; throws on a problem.
    $null = & ([IO.Path]::Combine($PSScriptRoot, '..', '.github', 'scripts', 'Get-LabelMap.ps1')) -LabelFilePath $LabelFilePath

    $lines = Get-Content -LiteralPath $LabelFilePath | Where-Object { $_ -notmatch '^\s*//' }
    $desired = @((($lines -join "`n") | ConvertFrom-Json).labels | ForEach-Object { ConvertTo-LabelRecord $_ })

    $remoteJson = gh api "repos/$Owner/$Repository/labels" --paginate
    if ($LASTEXITCODE -ne 0) {
        throw "Could not list the labels of $Owner/$Repository. Check the gh login and the repository name."
    }

    $remote = @(($remoteJson | ConvertFrom-Json) | ForEach-Object { ConvertTo-LabelRecord $_ })
    $plan = Get-LabelPlan -Desired $desired -Remote $remote

    Write-Information "Create $($plan.Create.Count), update $($plan.Update.Count), remove $($plan.Remove.Count) label(s) in $Owner/$Repository." -InformationAction Continue
    foreach ($label in $plan.Create) { Write-Information "  + $($label.Name)" -InformationAction Continue }
    foreach ($label in $plan.Update) { Write-Information "  ~ $($label.Name)" -InformationAction Continue }
    foreach ($label in $plan.Remove) { Write-Information "  - $($label.Name)" -InformationAction Continue }

    foreach ($rename in $plan.Renames) {
        Write-Warning "Likely rename: '$($rename.From)' is removed and '$($rename.To)' is created. Issues lose the old label."
    }

    Import-Module MSCKite.Azure.Platform
    if (-not $Apply) {
        $null = Set-GitHubLabels -LabelFilePath $LabelFilePath -Owner $Owner -Repository $Repository -WhatIf
        Write-Information 'Dry run. Nothing was changed. Run again with -Apply to sync.' -InformationAction Continue
        return $plan
    }

    if ($plan.Renames.Count -gt 0 -and -not $Force) {
        throw 'A likely rename was found. Nothing was changed. Pass -Force to continue.'
    }

    $result = Set-GitHubLabels -LabelFilePath $LabelFilePath -Owner $Owner -Repository $Repository -Confirm:$false
    Write-Information "Added $($result.Added.Count), updated $($result.Updated.Count), removed $($result.Removed.Count), unchanged $($result.Unchanged.Count)." -InformationAction Continue

    $again = Set-GitHubLabels -LabelFilePath $LabelFilePath -Owner $Owner -Repository $Repository -Confirm:$false
    if ($again.Added.Count + $again.Updated.Count + $again.Removed.Count -gt 0) {
        throw "The second run still changed labels (added $($again.Added.Count), updated $($again.Updated.Count), removed $($again.Removed.Count)). Check the label file."
    }

    Write-Information "Verified: a second run changed nothing ($($again.Unchanged.Count) unchanged)." -InformationAction Continue
    $plan
}

# Dot-sourcing only defines the functions.
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-LabelSync -Owner $Owner -Repository $Repository -LabelFilePath $LabelFilePath -Apply:$Apply -Force:$Force
}
