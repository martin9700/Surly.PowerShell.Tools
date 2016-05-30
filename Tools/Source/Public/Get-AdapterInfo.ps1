Function Get-AdapterInfo {
    <#
    .SYNOPSIS
        List basic network adapter information for selected computers
    .DESCRIPTION
        Script will list Computer Name, Interface Name, IP Address (v4 and v6) and
        MAC address for specified computers.
    
        Script will accept pipeline data from Get-Content, Get-ADComputer and just
        about anything that will pass on just a computer name (see examples below).
    
        * Requires PowerShell 3.0 or higher to run.
        * Will only work on Windows Server 2008 and greater or Vista and greater.
    
    .PARAMETER Name
        Specify the name of the computer from which you want to retrieve information.
    .PARAMETER IPv4Only
        Have the script display only IPv4 addresses
    .INPUTS
        Microsoft.ActiveDirectory.Management.ADComputer
    .OUTPUTS
        PSCustomObject
            ComputerName
            InterfaceName
            IPAddress
            MacAddress
    .EXAMPLE
        .\Get-AdapterInfo.ps1 -ComputerName MyComputer,YourComputer
    
        Display adapter information for MyComputer and YourComputer.
    .EXAMPLE
        Get-Content c:\scripts\ComputerNames.txt | .\Get-AdapterInfo.ps1 -IPv4Only
        or
        .\Get-AdapterInfo.ps1 -ComputerName (Get-Content c:\scripts\ComputerNames.txt) -IPv4Only
    
        Display adapter information for all computers in ComputerNames.txt but only display
        IPv4 IP addresses.
    .EXAMPLE
        Get-ADComputer -Filter * | .\Get-AdapterInfo.ps1
    
        Display adapter information for all computers in Active Directory
    .NOTES
        Author:             Martin Pugh
        Twitter:            @thesurlyadm1n
        Spiceworks:         Martin9700
        Blog:               www.thesurlyadmin.com
       
        Changelog:
            1.0             Initial Release
            1.1             Updated to use Get-WQLQuery
    .LINK
    
    #>
    #requires -Version 3.0
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [Alias("ComputerName")]
        [string[]]$Name = $Env:COMPUTERNAME,
        [Alias("IPv4")]
        [switch]$IPv4Only
    )
    Begin {
        Write-Verbose "$(Get-Date): Script Begins!"
        If ($IPv4Only)
        {   Write-Verbose "$(Get-Date): Filtering out IPv6 addresses"
        }
    }

    Process {
        ForEach ($Computer in $Name)
        {   Write-Verbose "$(Get-Date): Working on $Computer..."
            Try {
                $Adapters = Get-WQLQuery -Query "Select * From Win32_NetworkAdapter Where NetEnabled = True" -ComputerName $Computer -ErrorAction Stop
            }
            Catch {
                Write-Error "$(Get-Date): Error getting adapter information because ""$_"""
                Continue
            }
        
            ForEach ($Adapter in $Adapters)
            {   
                $Config = Get-WQLQuery -Query "Select * From Win32_NetworkAdapterConfiguration Where Index = $($Adapter.Index)" -ComputerName $Computer
                ForEach ($IPAddr in $Config.IPAddress)
                {   If ($IPv4Only -and $IPAddr -like "*:*")
                    {   Continue
                    }
                    [PSCustomObject]@{
                        ComputerName = $Computer
                        InterfaceName = $Adapter.Name
                        IPAddress = $IPAddr
                        MACAddress = $Config.MACAddress
                    }
                }
            }
        }
    }

    End {
        Write-Verbose "$(Get-Date): Script completed!"
    }
}