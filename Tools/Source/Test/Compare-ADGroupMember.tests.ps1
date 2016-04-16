. $PSScriptRoot\..\Public\Compare-ADGroupMember.ps1

If (Test-Path $env:TEMP\GroupState.xml)
{
    Remove-Item $env:TEMP\GroupState.xml -Confirm:$false
}

Describe "Testing Compare-ADGroupMember" {
    Mock Get-ADUser { Return [PSCustomObject]@{ SamAccountName = "tsa" } } -ParameterFilter {$Change.InputObject -eq "TheSurlyAdmin"}
    Mock Get-ADUser { Return [PSCustomObject]@{ SamAccountName = "tsk" } } -ParameterFilter {$Change.InputObject -eq "TheSurlyKid"}
    Mock Get-ADUser { Return [PSCustomObject]@{ SamAccountName = "tsw" } } -ParameterFilter {$Change.InputObject -eq "TheSurlyWife"}

    Context "Testing Adds" {
        It "Test first add" {
            Mock Get-ADGroup { Return [PSCustomObject]@{ Member = @("TheSurlyAdmin") } }
            (Compare-ADGroupMember -Name SurlyGroup1).Change | Should Be "Group added to watch"
        }

        It "Test that groupstate.xml was created" {
            Test-Path $env:TEMP\GroupState.xml | Should Be $true
        }

        It "Test add a group to watch" {
            Mock Get-ADGroup { Return [PSCustomObject]@{ Member = @("TheSurlyAdmin") } } -ParameterFilter {$Group -eq 'SurlyGroup1'}
            Mock Get-ADGroup { Return [PSCustomObject]@{ Member = @("TheSurlyWife") } } -ParameterFilter {$Group -eq 'SurlyGroup2'}
            (Compare-ADGroupMember -Name SurlyGroup1,SurlyGroup2).Group | Should Be "SurlyGroup2"
        }

        It "Test new user in group 1" {
            Mock Get-ADGroup { Return [PSCustomObject]@{ Member = @("TheSurlyAdmin","TheSurlyKid") } } -ParameterFilter {$Group -eq 'SurlyGroup1'}
            Mock Get-ADGroup { Return [PSCustomObject]@{ Member = @("TheSurlyWife") } } -ParameterFilter {$Group -eq 'SurlyGroup2'}

            $Compare = Compare-ADGroupMember -Name SurlyGroup1,SurlyGroup2
            $Compare.Change | Should Be "Added"
            $Compare.UserName | Should Be "tsk"
        }

        It "Test new user in group 2" {
            Mock Get-ADGroup { Return [PSCustomObject]@{ Member = @("TheSurlyAdmin","TheSurlyKid") } } -ParameterFilter {$Group -eq 'SurlyGroup1'}
            Mock Get-ADGroup { Return [PSCustomObject]@{ Member = @("TheSurlyWife","TheSurlyAdmin") } } -ParameterFilter {$Group -eq 'SurlyGroup2'}

            $Compare = Compare-ADGroupMember -Name SurlyGroup1,SurlyGroup2
            $Compare.Change | Should Be "Added"
            $Compare.UserName | Should Be "tsa"
        }

        It "Test for group not found, should see warning message for SurlyGroup3 (line above)" {
            Mock Get-ADGroup { Return [PSCustomObject]@{ Member = @("TheSurlyAdmin","TheSurlyKid") } } -ParameterFilter {$Group -eq 'SurlyGroup1'}
            Mock Get-ADGroup { Return [PSCustomObject]@{ Member = @("TheSurlyWife","TheSurlyAdmin") } } -ParameterFilter {$Group -eq 'SurlyGroup2'}
            Mock Get-ADGroup { Throw } -ParameterFilter {$Group -eq 'SurlyGroup3'}

            Compare-ADGroupMember -Name SurlyGroup1,SurlyGroup2,SurlyGroup3 | Should BeNullorEmpty
        }
    }

    Context "Testing Removes" {
        It "Remove group from watch" {
            Mock Get-ADGroup { Return [PSCustomObject]@{ Member = @("TheSurlyAdmin","TheSurlyKid") } } -ParameterFilter {$Group -eq 'SurlyGroup1'}

            (Compare-ADGroupMember -Name SurlyGroup1).Change | Should Be "Group removed from watch"
        }

        It "Remove User from group" {
            Mock Get-ADGroup { Return [PSCustomObject]@{ Member = @("TheSurlyAdmin") } } -ParameterFilter {$Group -eq 'SurlyGroup1'}

            (Compare-ADGroupMember -Name SurlyGroup1).Change | Should Be "Removed"
        }

        It "Delete group" {
            Mock Get-ADGroup { Throw } -ParameterFilter {$Group -eq 'SurlyGroup1'}
            (Compare-ADGroupMember -Name SurlyGroup1).Change | Should Be "Group deleted"
        }

        It "Check for bad path" {
            {Compare-ADGroupMember -Name SurlyGroup1 -Path "c:\this\is\an\impossible\path"} | Should Throw
        }
    }
}