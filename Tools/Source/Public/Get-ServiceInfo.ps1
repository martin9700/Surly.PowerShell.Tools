Function Get-ServiceInfo
{	<#
	.SYNOPSIS
		Get extended service information that Get-Service does not provide.
	.DESCRIPTION
		This function returns information about Windows services that is not included
		in Get-Service.  The function accepts both a command line parameter, or server
		names from the pipeline.

        Since this is a function, save the file as Get-ServiceInfo.ps1 and dot source it
        load into memory:

        . .\Get-ServiceInfo.ps1

    .PARAMETER Name
        Enter the computer name or names of the computers you want to query.

    .PARAMETER Filter
        Enter the service display name you wish to query for.  Wildcards are permitted.

    .INPUTS
        Pipeline
        Any object where a computer name is in the Name property (Get-ADComputer)
    .OUTPUTS
        PSCustomObject
            ComputerName
            DisplayName
            Name
            StartMode
            ServiceLogin
            State
    .EXAMPLE
        Get-ServiceInfo

        Displays all services on the local machine

    .EXAMPLE
        Get-ServiceInfo -Name Server1,Server2 -Filter Netlog*

        Return all services on Server1 and Server2 that begin with NetLog*

    .EXAMPLE
        Get-ServiceInfo -Name (Get-Content c:\scripts\serverlist.txt) -Filter *SQL*

        Get all services on computers listed in serverlist.txt and only return the ones that have
        SQL in their display name.

    .EXAMPLE
        Get-ADComputer -Filter {Name -like "SQL*"} | Get-ServiceInfo -Filter *SQL*

        Query Active Directory for every computer that starts with SQL and return all services on them
        that have the word SQL in their display name.

    .NOTES
        Author:             Martin Pugh
        Twitter:            @thesurlyadm1n
        Spiceworks:         Martin9700
        Blog:               www.thesurlyadmin.com
      
        Changelog:
            1.0             Initial Release
            2.0             Complete rewrite.  Supports pipeline as text as well as object, converted to PS3.0 with Get-CimInstance, 
                            output objects in stream, added display name search.  
	.LINK
		http://www.thesurlyadmin.com/2012/09/06/get-service-information-for-a-list-of-computers
    .LINK
		http://community.spiceworks.com/scripts/show/1639-get-serviceinformation-extended
	#>
    #requires -version 3.0
	Param(
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [Alias("ComputerName")]
		[string[]]$Name = $env:computername,
        [string[]]$Filter = "*"
		)
	Begin
	{	Write-Verbose "$(Get-Date): Get-ServiceInfo begins"
	}
	Process
	{	
        ForEach ($Computer in $Name)
        {
            Write-Verbose "$(Get-Date): Working on $Computer"
            ForEach ($Service in $Filter)
            {
                $CimParams = @{
                    ClassName = "Win32_Service"
                    ComputerName = $Computer
                }
                If ($Service -ne "*")
                {
                    $CimParams.Add("Filter","DisplayName like '$($Service.Replace('*','%'))'")
                }
                Get-WmiObject @CimParams | Select @{Name="ComputerName";Expression={$Computer}},DisplayName,Name,StartMode,@{Name="ServiceLogon";Expression={$_.StartName}},State
            }
        }
    }
    End
	{
        Write-Verbose "$(Get-Date): Get-ServiceInfo completed"
	}
}


Get-ServiceInfo -filter *store*,netlog*