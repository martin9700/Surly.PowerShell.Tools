. $PSScriptRoot\..\Public\Get-ServiceInfo.ps1

Describe "Testing Get-ServiceInfo" {
    Context "Getting general service information" {
        It "Test simple spooler information" {
            (Get-ServiceInfo -Filter "*spooler*").Name | Should Be "Spooler"
        }

        It "Test multiple service filters" {
            $Test = Get-ServiceInfo -Filter "*spool*","*remote m*"
            $Test[0].Name | Should Be "Spooler"
            $Test[1].Name | Should Be "WinRM"
        }

        It "Test bad computer name" {
            Get-ServiceInfo -Name "badcomputername" -ErrorAction SilentlyContinue | Should BeNullorEmpty
        }

        It "Test pipeline input" {
            ("localhost" | Get-ServiceInfo -Filter "*spool*").Name | Should Be "Spooler"
        }

        It "Test multiple service filters with multiple pipeline input" {
            $Test = ".","localhost" | Get-ServiceInfo -Filter "*spool*","*remote m*"
            $Test[0].Name | Should Be "Spooler"
            $Test[1].Name | Should Be "WinRM"
            $Test[2].Name | Should Be "Spooler"
            $Test[3].Name | Should Be "WinRM"
        }
        
        It "Test badcomputer name from pipeline" {
            "badcomputername" | Get-ServiceInfo -ErrorAction SilentlyContinue | Should BeNullorEmpty
        }
    }
}