#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    . ([IO.Path]::Combine($PSScriptRoot, '..', 'Sync-Labels.ps1')) -Owner 'o' -Repository 'r'

    function Get-TestLabel {
        param([string]$Name, [string]$Color = 'ffffff', [string]$Description = '')

        [pscustomobject]@{ Name = $Name; Color = $Color; Description = $Description }
    }
}

Describe 'ConvertTo-LabelRecord' {
    It 'normalizes the color and a missing description' {
        $record = ConvertTo-LabelRecord ([pscustomobject]@{ name = 'bug'; color = '#D73A4A' })
        $record.Color | Should -Be 'd73a4a'
        $record.Description | Should -Be ''
    }
}

Describe 'Get-LabelPlan' {
    It 'finds nothing to do when the labels match' {
        $label = Get-TestLabel 'bug' 'd73a4a' 'Something is wrong'
        $plan = Get-LabelPlan -Desired @($label) -Remote @($label)
        $plan.Create.Count | Should -Be 0
        $plan.Update.Count | Should -Be 0
        $plan.Remove.Count | Should -Be 0
        $plan.Renames.Count | Should -Be 0
    }

    It 'creates, updates and removes by name' {
        $desired = @((Get-TestLabel 'new'), (Get-TestLabel 'changed' 'ff0000'))
        $remote = @((Get-TestLabel 'changed' '00ff00'), (Get-TestLabel 'old' '123456' 'x'))
        $plan = Get-LabelPlan -Desired $desired -Remote $remote
        $plan.Create.Name | Should -Be 'new'
        $plan.Update.Name | Should -Be 'changed'
        $plan.Remove.Name | Should -Be 'old'
        $plan.Renames.Count | Should -Be 0
    }

    It 'flags a likely rename: same color and description, other name' {
        $desired = @((Get-TestLabel 'in progress :rocket:' 'e8e8e8' 'Work started'))
        $remote = @((Get-TestLabel 'in progress :dart:' 'e8e8e8' 'Work started'))
        $plan = Get-LabelPlan -Desired $desired -Remote $remote
        $plan.Renames.Count | Should -Be 1
        $plan.Renames[0].From | Should -Be 'in progress :dart:'
        $plan.Renames[0].To | Should -Be 'in progress :rocket:'
    }

    It 'handles a repository without labels' {
        $plan = Get-LabelPlan -Desired @((Get-TestLabel 'bug')) -Remote @()
        $plan.Create.Count | Should -Be 1
        $plan.Remove.Count | Should -Be 0
    }
}

Describe 'Invoke-LabelSync' {
    It 'stops when the label file does not exist' {
        { Invoke-LabelSync -Owner 'o' -Repository 'r' -LabelFilePath 'C:\does-not-exist.jsonc' } | Should -Throw '*not found*'
    }
}
