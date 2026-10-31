#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    . ([IO.Path]::Combine($PSScriptRoot, '..', 'Get-AgentToken.ps1')) -ClientId 'Iv1.test'

    function ConvertFrom-Base64Url {
        param([string]$Value)

        $padded = $Value.Replace('-', '+').Replace('_', '/')
        $padded = $padded.PadRight($padded.Length + (4 - $padded.Length % 4) % 4, '=')
        [Convert]::FromBase64String($padded)
    }

    $script:rsa = [Security.Cryptography.RSA]::Create(2048)
    $script:pem = $script:rsa.ExportPkcs8PrivateKeyPem()
}

AfterAll {
    $script:rsa.Dispose()
}

Describe 'Get-AppJwt' {
    BeforeAll {
        $now = [datetime]::new(2026, 1, 1, 12, 0, 0, [DateTimeKind]::Utc)
        $script:jwt = Get-AppJwt -ClientId 'Iv1.test' -PrivateKeyPem $script:pem -Now $now
        $script:parts = $script:jwt.Split('.')
    }

    It 'has three url-safe segments' {
        $script:parts.Count | Should -Be 3
        $script:jwt | Should -Not -Match '[+/=]'
    }

    It 'uses RS256 and carries the client id as issuer' {
        $header = [Text.Encoding]::UTF8.GetString((ConvertFrom-Base64Url $script:parts[0])) | ConvertFrom-Json
        $claims = [Text.Encoding]::UTF8.GetString((ConvertFrom-Base64Url $script:parts[1])) | ConvertFrom-Json
        $header.alg | Should -Be 'RS256'
        $claims.iss | Should -Be 'Iv1.test'
    }

    It 'is valid for at most 10 minutes and starts in the past' {
        $claims = [Text.Encoding]::UTF8.GetString((ConvertFrom-Base64Url $script:parts[1])) | ConvertFrom-Json
        $issued = [DateTimeOffset]::new([datetime]::new(2026, 1, 1, 12, 0, 0, [DateTimeKind]::Utc)).ToUnixTimeSeconds()
        $claims.iat | Should -BeLessThan $issued
        ($claims.exp - $claims.iat) | Should -BeLessOrEqual 600
    }

    It 'has a signature that verifies with the public key' {
        $data = [Text.Encoding]::UTF8.GetBytes("$($script:parts[0]).$($script:parts[1])")
        $signature = ConvertFrom-Base64Url $script:parts[2]
        $script:rsa.VerifyData($data, $signature, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) | Should -BeTrue
    }
}

Describe 'Get-AgentToken' {
    It 'stops without a client id' {
        { Get-AgentToken -ClientId '' -Owner 'o' -Repository 'r' -VaultName 'v' -SecretName 's' } | Should -Throw '*Client ID*'
    }
}

Describe 'Start-Agent.ps1' {
    It 'shows the steps with -WhatIf and creates no token' {
        $output = & ([IO.Path]::Combine($PSScriptRoot, '..', 'Start-Agent.ps1')) -ClientId 'Iv1.test' -WhatIf 6>&1 | Out-String
        $output | Should -Match 'Get an installation token'
        $env:GH_TOKEN | Should -BeNullOrEmpty
    }

    It 'stops with a clear message when ClaudePath does not exist' {
        $script = [IO.Path]::Combine($PSScriptRoot, '..', 'Start-Agent.ps1')
        { & $script -ClientId 'Iv1.test' -ClaudePath 'C:\does-not-exist\claude.exe' } | Should -Throw '*does not exist*'
        $env:GH_TOKEN | Should -BeNullOrEmpty
    }
}
