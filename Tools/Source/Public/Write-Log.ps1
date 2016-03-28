Function Write-Log
{   <#
    .SYNOPSIS
        Function to write event to the Windows application log
    .DESCRIPTION
        The purpose of this function is to have a single method of writing events to the Windows
        event log.  Any script that requires some kind of logging--essentially if you are making
        a change to Active Diretory objects, Exchange, etc then you should be logging that change
        with this function.
        
    .PARAMETER Source
        This is the source of the event.  By default it will be the name of the script calling
        the function.
        
    .PARAMETER ID
        ID number to be used for the event entry.  
        
    .PARAMETER Type
        Event type, which can be Error, Warning or Information.  You can use E, W or I for short.
        
    .PARAMETER Message
        The actual message you want to be put into the event entry.

    .PARAMETER ComputerName
        The computer that you want the event to be written to. Defaults to currrent computer name.
        
    .INPUTS
        None
    .OUTPUTS
        None
    .EXAMPLE
        #Script Name:test.ps1
        Import-Module \\opsadmin101\Scripts\Functions\Write-Log.psm1
        Write-Log -Message "This is a test"
        
        This will create an event log entry from source test.ps1, ID 1, Information type.  The Message
        will be "This is a test".
        
    .EXAMPLE
        #Script Name:Remove-AllUsers.ps1
        Import-Module \\opsadmin101\Scripts\Functions\Write-Log.psm1
        Write-Log -ID 999 -Source "DeleteAll" -Type W -Message "Deleting all users from Active Directory.  Is your Desk packed?"
        
        This example uses a custom source of "DeleteAll" and will create a warning event log entry.
        
    .EXAMPLE
        #Script Name:test.ps1
        Import-Module \\opsadmin101\Scripts\Functions\Write-Log.psm1
        Write-Log -Message "Unlocking account for $User" -Verbose
        
        Write a simple information log entry and echo the results in verbose output.  This switch will trigger verbose output
        regardless if your script (in this example, test.ps1) is in verbose mode.
        
    .NOTES
        Author:             Martin Pugh
        Date:               9/18/2014
          
        Changelog:
            09/18/14        MLP - Initial Release
            11/19/14        RB - Added support for writing to remote computer
            11/22/14        MLP - Added "WhatIf" support
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Source = (Split-Path -Path $MyInvocation.ScriptName -Leaf),
        [Int32]$ID = 1,
        [ValidateSet("Error","Warning","Information","E","W","I")]
        [string]$Type = "Information",
        [string]$ComputerName = $env:COMPUTERNAME
    )
    
    Switch ($Type)
    {   "e" { $Type = "Error"; Break }
        "w" { $Type = "Warning"; Break }
        "i" { $Type = "Information"; Break }
    }
    
    If (-not [System.Diagnostics.EventLog]::SourceExists($Source,$ComputerName))
    {   New-EventLog -LogName Application -Source $Source -ComputerName $ComputerName
    }
    Write-EventLog -EntryType $Type -EventId $ID -LogName Application -Message "$($Source): $Message" -Source $Source -Category 0 -ComputerName $ComputerName
    Write-Verbose "[$(Get-Date)]: Source: $Source  Type: $Type :: $Message"
}


write-log -id 99 -Type Error -Message "Testimg..."