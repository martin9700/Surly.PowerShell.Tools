Function Get-OUFullyQualifiedDomainName {
	<#
	.SYNOPSIS
		Find out the full LDAP FQDN for an OU in your Active Directory and copy it into your clipboard.
	.DESCRIPTION
		More and more Powershell scripts are using LDAP to locate items within Active Directory, but
		finding out what that full FQDN is can be a pain.  This script aims to make finding the full
		FQDN for Organizational Units in your Active Directory easier by presenting you with a simple
		list of all the OU's and letting you select which one you want.  The resulting FQDN is then
		copied into the clipboard for whatever you need it for.
		
		I recommend adding this Function into your $Profile so you can call it from any Powershell
		command prompt.  To read more about the Powershell $Profile go here:
		
		http://technet.microsoft.com/en-us/library/ee692764.aspx
	.PARAMETER Search
		Enter a string value and Get-OUFullyQualifiedDomainName will only present you with a list of OU's that have
		that string value in them.  The search is NOT case sensitive.
	.EXAMPLE
		Get-OUFullyQualifiedDomainName
		Will present a listing of all of your OU's which you can select from.  Enter the
		cooresponding number and the FQDN will be copied to your clipboard.
	.EXAMPLE
		Get-OUFullyQualifiedDomainName -Search Computers
		Will present a listing of all of your OU's that have the word "computers" in them.
	.OUTPUT
		FQDN of the selected OU into the Windows clipboard
    .NOTES
        Author:             Martin Pugh
        Twitter:            @thesurlyadm1n
        Spiceworks:         Martin9700
        Blog:               www.thesurlyadmin.com
      
        Changelog:
            2.0             Complete rewrite.  Using Out-Gridview now
            1.0             Initial Release

	.LINK
		http://technet.microsoft.com/en-us/library/ee692764.aspx
		
	#>
    [CmdletBinding()]
	Param (
		[string]$Search
	)
	
	Import-Module ActiveDirectory -ErrorAction SilentlyContinue
    Try {
        $OUs = @(Get-ADOrganizationalUnit -Filter * -ErrorAction Stop | Where { $_.distinguishedname -like "*$Search*" })
    }
    Catch {
        Throw "Get-ADOrganizationalUnit failed because ""$($Error[0])"""
    }
    If ($OUs.Count -eq 0)
    {
        Write-Warning "No OU's found"
    }
    ElseIf ($OUs.Count -eq 1)
    {
        $Result = $OUs | Select Name,distinguishedName
    }
    Else
    {
	    $Result = $OUs | Sort Name | Select Name,distinguishedName | Out-GridView -Title "Select Organization Unit" -PassThru
    }
    If ($Result)
    {
    	Write-Verbose "$($Result.distinguishedName) copied to clipboard" -Verbose
		[Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
        [Windows.Forms.Clipboard]::SetDataObject($Result.distinguishedName, $true)
	}
}
