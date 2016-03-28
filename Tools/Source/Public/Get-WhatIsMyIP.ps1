Function Get-WhatIsMyIP
{   <#
    .SYNOPSIS
        Simple function to retrieve your public IP address
    .DESCRIPTION
        Script uses checkIP.dyndns.org to retrieve your Public IP address.  Script
        will also do a reverse DNS lookup of the IP address and get the host name,
        if it's available.
    .PARAMETER URL
        URL to checkip.dyndns.org.  Update this parameter if DynDNS changes it for
        some reason.  
    .EXAMPLE
        Get-WhatIsMyIP
        
        Returns your public IP address and computer name, if the script
        can resolve the IP address.
        
        ComputerName                                                         PublicIP                                                            
        ------------                                                         --------                                                            
        c-99-217-203-255.hsd1.ma.comcast.net                                 99.217.203.255
    .NOTES
        Author:            Martin Pugh
        Twitter:           @thesurlyadm1n
        Spiceworks:        Martin9700
        Blog:              www.thesurlyadmin.com
           
        Changelog:
           1.0             Initial Release  
    #>
    Param (
        [string]$URL = "http://checkip.dyndns.org"
    )

    Try {
        $WebRequest = Invoke-WebRequest $URL -ErrorAction Stop

        If ($WebRequest -match "\b(?:\d{1,3}\.){3}\d{1,3}\b")
        {   $IP = $Matches[0]
            $Ping = Get-WMIObject Win32_PingStatus -Filter "Address = '$IP' AND ResolveAddressNames = TRUE"
            If ($Ping.StatusCode -eq 0)
            {   $ComputerName = $Ping.ProtocolAddressResolved
            }
            Else
            {   $ComputerName = "Unable to resolve"
            }
            New-Object PSObject -Property @{
                ComputerName = $ComputerName
                PublicIP = $IP
            }
        }
        Else
        {   Write-Warning "Unable to resolve public IP address"
        }
    }
    Catch {
        Write-Warning "Web connection failed"
    }
}
