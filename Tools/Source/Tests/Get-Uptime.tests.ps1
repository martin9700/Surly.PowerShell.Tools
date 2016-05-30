. $PSScriptRoot\..\Public\Get-Uptime.ps1
. $PSScriptRoot\..\Public\Get-WQLQuery.ps1

Describe "Testing Get-Uptime" {
    Context "Test retrieve uptime information " {
        It "Test 1 server" {
            $Test = (Get-Uptime).LastBootTIme -lt (Get-Date)
            $Test | Should Be $true
        }

        It "Test 2 servers" {
            $Data = Get-Uptime -Name ".","localhost"
            $Test1 = $Data[0].LastBootTime -lt (Get-Date)
            $Test2 = $Data[1].LastBootTime -lt (Get-Date)
            $Test1 | Should Be $true
            $Test2 | Should Be $true
        }

        It "Test a bad server name (should be a warning above)" {
            Get-Uptime -Name "badservername"
            $true | Should Be $true
        }

        It "Test 2 servers in pipeline and bad server name" {
            $Data = ".","localhost","badservername" | Get-Uptime
            $Test1 = $Data[0].LastBootTime -lt (Get-Date)
            $Test2 = $Data[1].LastBootTime -lt (Get-Date)
            $Test1 | Should Be $true
            $Test2 | Should Be $true
        }
    }
}