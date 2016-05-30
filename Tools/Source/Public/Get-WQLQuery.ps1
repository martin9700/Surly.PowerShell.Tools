
Function Get-WQLQuery
{   
    <#
    .SYNOPSIS
        Replacement for Get-WmiObject and Get-CimInstance
    .DESCRIPTION
        Function will take a WQL Query and attempt to use WSMAN to accomplish the query, and if that fails
        it will attempt to use DCOM (the default protocol used for WMI calls prior to Windows 2008 R2).
    .PARAMETER Name
        Name of the computer you wish to query
    .PARAMETER Query
        This is the WQL text
    .PARAMETER NameSpace
        The WMI namespace you are querying against
    .PARAMETER Credential
        Alternative credentials to use for the query
    .PARAMETER Protocol
        You can specify WSMAN or DCOM specifically and the script will not automatically attempt
        both.
    .INPUTS
    .OUTPUTS
    .EXAMPLE
        Get-WQLQuery -Query "Select * From Win32_ComputerSystem" -ComputerName RemoteServer

    .NOTES
        Author:             Martin Pugh
        Twitter:            @thesurlyadm1n
        Spiceworks:         Martin9700
        Blog:               www.thesurlyadmin.com
      
        Changelog:
            1.0             Initial Release
            2.0             Rewrite for publish to Surly.PowerShell.Tools.  Removed "retries", simplified protocol
                            failover.  Added comment based help.  Added pipeline for computername
    .LINK
        https://github.com/martin9700/Surly.PowerShell.Tools
    #>
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [Alias("ComputerName")]
        [string[]]$Name = $Env:COMPUTERNAME,
        [string]$Query,
        [string]$NameSpace = "root\CIMV2",
        [System.Management.Automation.PSCredential]$Credential,
        [ValidateSet($null,"WSMAN","DCOM")]
        [string]$Protocol
    )
    
    Begin {
        Write-Verbose "$(Get-Date): Get-WQLQuery Begins"
    }

    Process {
        ForEach ($ComputerName in $Name)
        {
            $SessionParams = @{
                ComputerName  = $ComputerName
            }
            If ($PSBoundParameters["Credential"])
            {   $SessionParams.Add("Credential",$Credential)
            }

            If ($Protocol)
            {
                [string[]]$Protocols = $Protocol
            }
            Else
            {
                $Protocols = "WSMAN","DCOM"
            }

            ForEach ($Protocol in $Protocols)
            {
                Write-Verbose "Attempting to connect to $ComputerName using $Protocol protocol"
                $SessionParams.SessionOption = New-CimSessionOption -Protocol $Protocol
                Try {
                    $CimSession = New-CimSession @SessionParams -ErrorAction Stop
                    Break
                }
                Catch {
                    $Protocol = $_
                }
            }
            If ($Protocol -notmatch "WSMAN|DCOM")
            {
                Write-Error "Unable to connect to $ComputerName because ""$Protocol""" -ErrorAction Stop
            }

            Try {
                $WMI = Get-CimInstance -CimSession $CimSession -Query $Query -ErrorAction Stop -Namespace $NameSpace
                $WMI | Add-Member -MemberType NoteProperty -Name WMIProtocol -Value $CimSession.Protocol
            }
            Catch {
                Write-Error "Unable to execute Query because ""$($_)"""
                Continue
            }
            Return $WMI
        }
    }

    End {
        Write-Verbose "$(Get-Date): Get-WQLQuery completed"
    }
}

cls
$Q = "Select * from Win32_bios where currentlanguage = 'en-us'"


    $R = Get-WQLQuery -Query $Q -Verbose
    $R | Fl *





