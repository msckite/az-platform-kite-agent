<#
.SYNOPSIS
    Maps label keys to label names for workflows.

.DESCRIPTION
    Reads a jsonc label file (see templates/github/other/github-labels.jsonc), validates the keys and writes a compact
    JSON object of key -> name to the output. Workflows act on the key, so consumers can rename labels freely.
    When GITHUB_OUTPUT is set, the map is also written there as the 'map' output.

.PARAMETER LabelFilePath
    Path of the jsonc label file.

.PARAMETER RequiredKeys
    Keys that must exist in the file. A missing key fails the run.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$LabelFilePath,

    [string[]]$RequiredKeys = @('todo', 'plan-proposed', 'approved', 'in-progress', 'in-pr', 'completed')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $LabelFilePath)) {
    throw "Label file not found: $LabelFilePath"
}

$json = (Get-Content -LiteralPath $LabelFilePath | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
$labels = ($json | ConvertFrom-Json).labels

$map = [ordered]@{}
foreach ($label in $labels) {
    if ([string]::IsNullOrWhiteSpace($label.key)) {
        throw "Label '$($label.name)' has no key."
    }

    if ($label.key -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
        throw "Label key '$($label.key)' is not kebab-case."
    }

    if ($map.Contains($label.key)) {
        throw "Duplicate label key '$($label.key)'."
    }

    $map[$label.key] = $label.name
}

$missing = $RequiredKeys | Where-Object { -not $map.Contains($_) }
if ($missing) {
    throw "Label file is missing required keys: $($missing -join ', ')."
}

$compact = $map | ConvertTo-Json -Compress
if ($env:GITHUB_OUTPUT) {
    "map=$compact" | Add-Content -LiteralPath $env:GITHUB_OUTPUT
}

$compact
