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
    $CurrentDomain = "LDAP://$(([ADSI]'').distinguishedName)"
    Try {
        $Search = [ADSISearcher]"(&(objectCategory=person)(objectClass=User)(SamAccountName=$($User.UserName)))"
        $ADUser = $Search.FindOne()
    }
    Catch {
        Write-Error "Unable to locate user $($User.Username) in $($Domain.DNSRoot)"
        Exit 1
    }

    Write-Verbose "Show user data and whether the password provided was good..."
    Write-verbose $ADUser
    Return [PSCustomObject]@{
        Name = $ADUser.properties.displayname[0]
        SamAccountName = $ADUser.properties.samaccountname[0]
        ValidPassword = ((New-Object DirectoryServices.DirectoryEntry $CurrentDomain,$User.UserName,$User.GetNetworkCredential().Password).PSBase.Name -ne $null)
        Enabled = If ($ADUser.properties.useraccountcontrol -eq 512) { $true } Else { $False }
        LockedOut = If ($ADUser.properties.lockouttime -eq 0) { $true } Else { $False }
        BadLogonCount = $ADUser.properties.badpwdcount[0]
        LastBadPasswordAttempt = [datetime]::FromFileTime([string]$ADuser.properties.badpasswordtime)
    }
}

#Test-ADAuthentication mpugh -verbose
