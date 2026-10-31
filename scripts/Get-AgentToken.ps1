<#
.SYNOPSIS
    Creates a short-lived GitHub App installation token for the agent.

.DESCRIPTION
    Reads the App private key from a PowerShell secret vault (never from a file), signs a JWT, and exchanges it for an
    installation token that is limited to one repository and expires after one hour. The key and the token are kept in memory
    only and are never written to disk or to a log.

    Dot-source the script to use Get-AppJwt, for example in tests. Running it returns an object with Token and ExpiresAt.

.PARAMETER ClientId
    Client ID of the GitHub App (shown on the App's General page). Not a secret. Defaults to $env:KITE_AGENT_CLIENT_ID.

.PARAMETER Owner
    Owner of the repository the token is limited to.

.PARAMETER Repository
    Repository the token is limited to.

.PARAMETER VaultName
    Name of the SecretManagement vault that holds the private key.

.PARAMETER SecretName
    Name of the secret that holds the private key (PEM text).
#>
[CmdletBinding()]
param(
    [string]$ClientId = $env:KITE_AGENT_CLIENT_ID,
    [string]$Owner = 'msckite',
    [string]$Repository = 'az-platform-kite-agent',
    [string]$VaultName = 'KiteAgent',
    [string]$SecretName = 'KiteAgentAppKey'
)

$ErrorActionPreference = 'Stop'

function ConvertTo-Base64Url {
    param([byte[]]$Bytes)

    [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

# Signs a GitHub App JWT (RS256). GitHub accepts at most 10 minutes; the issued-at time is set 60 seconds back for clock drift.
function Get-AppJwt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ClientId,

        [Parameter(Mandatory)]
        [string]$PrivateKeyPem,

        [datetime]$Now = [datetime]::UtcNow
    )

    $issuedAt = [DateTimeOffset]::new($Now.ToUniversalTime()).ToUnixTimeSeconds() - 60
    $header = @{ alg = 'RS256'; typ = 'JWT' } | ConvertTo-Json -Compress
    $claims = @{ iat = $issuedAt; exp = $issuedAt + 60 + 540; iss = $ClientId } | ConvertTo-Json -Compress
    $unsigned = '{0}.{1}' -f (ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes($header))), (ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes($claims)))

    $rsa = [Security.Cryptography.RSA]::Create()
    try {
        $rsa.ImportFromPem($PrivateKeyPem)
        $signature = $rsa.SignData(
            [Text.Encoding]::UTF8.GetBytes($unsigned),
            [Security.Cryptography.HashAlgorithmName]::SHA256,
            [Security.Cryptography.RSASignaturePadding]::Pkcs1)
    } finally {
        $rsa.Dispose()
    }

    '{0}.{1}' -f $unsigned, (ConvertTo-Base64Url $signature)
}

# Invoke-RestMethod already converts ISO 8601 strings to DateTime; parsing that value again as text fails in non-US cultures.
function ConvertTo-UtcDateTime {
    param([Parameter(Mandatory)]$Value)

    if ($Value -is [datetime]) {
        return $Value.ToUniversalTime()
    }

    [datetime]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal)
}

function Get-AgentToken {
    [CmdletBinding()]
    param(
        [string]$ClientId,
        [string]$Owner,
        [string]$Repository,
        [string]$VaultName,
        [string]$SecretName
    )

    if ([string]::IsNullOrWhiteSpace($ClientId)) {
        throw 'No Client ID. Pass -ClientId or set KITE_AGENT_CLIENT_ID (shown on the GitHub App General page).'
    }

    foreach ($name in 'Microsoft.PowerShell.SecretManagement') {
        if (-not (Get-Module -ListAvailable -Name $name)) {
            throw "Module $name is not installed. See docs/contributors/secret-management.md."
        }
    }

    $pem = Get-Secret -Name $SecretName -Vault $VaultName -AsPlainText -ErrorAction Stop
    try {
        $jwt = Get-AppJwt -ClientId $ClientId -PrivateKeyPem $pem
    } finally {
        $pem = $null
    }

    $headers = @{
        Authorization          = "Bearer $jwt"
        Accept                 = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
    }

    $installation = Invoke-RestMethod -Method Get -Uri "https://api.github.com/repos/$Owner/$Repository/installation" -Headers $headers
    $body = @{ repositories = @($Repository) } | ConvertTo-Json -Compress
    $response = Invoke-RestMethod -Method Post -Uri "https://api.github.com/app/installations/$($installation.id)/access_tokens" -Headers $headers -Body $body -ContentType 'application/json'

    [pscustomobject]@{
        Token     = $response.token
        ExpiresAt = ConvertTo-UtcDateTime $response.expires_at
    }
}

# Dot-sourcing only defines the functions.
if ($MyInvocation.InvocationName -ne '.') {
    # A variable saved with SetEnvironmentVariable(..., 'User') is not visible to terminals that were already open.
    if ([string]::IsNullOrWhiteSpace($ClientId)) {
        $ClientId = [Environment]::GetEnvironmentVariable('KITE_AGENT_CLIENT_ID', 'User')
    }

    Get-AgentToken -ClientId $ClientId -Owner $Owner -Repository $Repository -VaultName $VaultName -SecretName $SecretName
}
