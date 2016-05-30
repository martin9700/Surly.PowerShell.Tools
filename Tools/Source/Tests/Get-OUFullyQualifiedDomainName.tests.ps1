. $PSScriptRoot\..\Public\Get-OUFullyQualifiedDomainName.ps1

[Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
Function Get-Clipboard {
    $TextBox = New-Object System.Windows.Forms.TextBox
    $TextBox.Multiline = $true
    $TextBox.Paste()
    Return $TextBox.Text
}


Describe "Testing Get-OUFullyQualifiedDomainName" {
    #Can't test Out-Gridview, so have to test everything else
    Context "Test default settings" {
        Mock Get-ADOrganizationalUnit { Return [PSCustomObject]@{Name="SurlyOU1";distinguishedName="OU=SurlyOU1,DC=thesurlyadmin,DC=com"} }

        It "Test with 1 OU" {
            Get-OUFullyQualifiedDomainName
            Get-Clipboard | Should Be "OU=SurlyOU1,DC=thesurlyadmin,DC=com"
        }

        It "Test Search parameter" {
            Mock Get-ADOrganizationalUnit { Return @([PSCustomObject]@{Name="SurlyOU1";distinguishedName="OU=SurlyOU1,DC=thesurlyadmin,DC=com"},[PSCustomObject]@{Name="SurlyOU2";distinguishedName="OU=SurlyOU2,DC=thesurlyadmin,DC=com"}) }

            Get-OUFullyQualifiedDomainName -Search SurlyOU2
            Get-Clipboard | Should Be "OU=SurlyOU2,DC=thesurlyadmin,DC=com"
        }

        It "Test Error catching" {
            Mock Get-ADOrganizationalUnit { Throw }

            {Get-OUFullyQualifiedDomainName} | Should Throw
        }
    }
}
