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
	.LINK
		http://technet.microsoft.com/en-us/library/ee692764.aspx
		
	#>
	Param (
		[string]$Search
	)
	
	Import-Module ActiveDirectory -ErrorAction SilentlyContinue
	$OUs = Get-ADOrganizationalUnit -Filter * | Where { $_.distinguishedname -like "*$Search*" } | Sort Name
	$MenuItem = 0
	cls
	Write-Host "Select the OU you want and the LDAP value will be copied to the clipboard.`n"
	ForEach ($OU in $OUs)
	{	$MenuItem ++
		$MenuText = ($OU | Select Name,DistinguishedName | Format-Table -HideTableHeaders | Out-String).Trim()
		If ($MenuItem -lt 10)
		{	[string]$Select = " $MenuItem"
		}
		Else
		{	[string]$Select = $MenuItem
		}
		Write-Host "$Select. $MenuText"
	}
	$Prompt = Read-Host -Prompt "`n`nEnter number of the OU you want"
	If (-not $Prompt)
	{	Break
	}
	Try 
	{	$Prompt = [int]$Prompt
	}
	Catch
	{	Write-Host "`nSorry, invalid entry.  Try again!"
		Break
	}
	If ($Prompt -lt 1 -or $Prompt -gt $MenuItem)
	{	Write-Host "`nSorry, invalid entry.  Try again!"
	}
	Else
	{	Write-Host "`n`n$($OUs[$Prompt - 1].distinguishedName) copied to clipboard"
		[Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
        [Windows.Forms.Clipboard]::SetDataObject($OUs[$Prompt - 1].distinguishedName, $true)
	}
}
