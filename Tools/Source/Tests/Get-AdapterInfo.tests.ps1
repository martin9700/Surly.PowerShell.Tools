. $PSScriptRoot\..\Public\Get-AdapterInfo.ps1
. $PSScriptRoot\..\Public\Get-WQLQuery.ps1



Describe "Testing Get-AdapterInfo" {
    Context "Non-pipeline tests" {
        It "Get localhost adapter" {
            (Get-AdapterInfo).ComputerName | Should Be "appveyor-vm"
        }

        It "Test two computers" {
            $Test = Get-AdapterInfo -Name "appveyor-vm","localhost"
            $Test[0].ComputerName | Should Be "appveyor-vm"
            $Test[1].ComputerName | Should Be "localhost"
        }

        It "Filter out IPV6" {
            (Get-AdapterInfo -IPv4Only).ComputerName | Should Be "appveyor-vm"
        }

        It "Bad computer name (should see warning above)" {
            Get-AdapterInfo -Name NoComputerHere -ErrorAction SilentlyContinue | Should BeNullorEmpty
        }
    }

    Context "Pipeline tests" {
        It "Get localhost adapter from pipeline" {
            ("appveyor-vm" | Get-AdapterInfo).ComputerName | Should Be "appveyor-vm"
        }

        It "Test two computers in pipeline" {
            $PipeTest = "appveyor-vm","localhost" | Get-AdapterInfo
            $PipeTest[0].ComputerName | Should Be "appveyor-vm"
            $PipeTest[1].ComputerName | Should Be "localhost"
        }

        It "Get localhost adapter from pipeline, filter out IPv6" {
            ("appveyor-vm" | Get-AdapterInfo -IPv4Only).ComputerName | Should Be "appveyor-vm"
        }

        It "Bad computer name in pipeline (should see warning above)" {
            "NoComputerHere" | Get-AdapterInfo -ErrorAction SilentlyContinue | Should BeNullorEmpty
        }
    }
}
