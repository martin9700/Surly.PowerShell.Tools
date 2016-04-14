Function Test-ADAuthentication {
    <#
    .SYNOPSIS
        Test if a user's password is valid
    .PARAMETER User
        Requires a PSCredential object.  Will prompt automatically if nothing is provided.
    .INPUTS
        None
    .OUTPUTS
        PSCustomObject
    .EXAMPLE
        Test-ADAuthentication mpugh

        You will be prompted for password
    .EXAMPLE
        Test-ADAuthentication

        You will be prompted for username and password
    .NOTES
        Author:             Martin Pugh
        Date:               4/13/16
      
        Changelog:
            04/13           MLP - Initial Release
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [PSCredential]$User
    )

    Write-Verbose "Validating good username was provided..."
    $Domain = Get-ADDomain
    $CurrentDomain = "LDAP://$($Domain | Select -ExpandProperty distinguishedName)"
    Try {
        $ADUser = Get-ADUser $User.UserName -Properties LockedOut,LastBadPasswordAttempt,BadLogonCount
    }
    Catch {
        Throw "Unable to locate user $($User.Username) in $($Domain.DNSRoot)"
    }

    Write-Verbose "Show user data and whether the password provided was good..."
    $ADUser | Select Name,
        SamAccountName,
        @{Name="ValidPassword";Expression = { (New-Object DirectoryServices.DirectoryEntry $CurrentDomain,$User.UserName,$User.GetNetworkCredential().Password).PSBase.Name -ne $null }},
        Enabled,
        LockedOut,
        BadLogonCount,
        LastBadPasswordAttempt
}

#Test-ADAuthentication mpugh -verbose
