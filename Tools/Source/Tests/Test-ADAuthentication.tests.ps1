. $PSScriptRoot\..\Public\Test-ADAuthentication.ps1
#Import-Module ActiveDirectory -ErrorAction SilentlyContinue

Describe "Testing Test-ADAuthentication Success" {
    $FakePassword = ConvertTo-SecureString "FakePassword" -AsPlainText -Force
    $FakeCredential = New-Object PSCredential("FakeUser",$FakePassword)

    Context "Test User found" {
        $FakeUser = [PSCustomObject]@{
            Name = "The Surly Admin"
            SamAccountName = "Martin9700"
            Enabled = $true
            LockedOut = $False
            BadLogonCount = 1
            LastBadPasswordAttempt = Get-Date
        }
        $FakeResult = [PSCustomObject]@{Name="FakeUser"}
        $FakeResult.PSBase | Add-Member -MemberType NoteProperty -Name Name -Value "FakeUser"

        Mock New-Object { Return $FakeResult }
        Mock Get-ADUser { Return $FakeUser }
        Mock Get-ADDomain { Return [PSCustomObject]@{distinguishedName = "FakeDomain"} }
        
        It "Test successfully finding a user" {
            (Test-ADAuthentication -User $FakeCredential).ValidPassword | Should be $true
        }
    }
    Context "Test User not found" {
        It "Test NOT finding a user" {
            { Test-ADAuthentication -User $FakeCredential } | Should Throw
        }
    }
}
    