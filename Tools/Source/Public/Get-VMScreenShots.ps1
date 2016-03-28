Function Get-VMScreenShot {
    <# 
    .SYNOPSIS
	    Get-VMScreenshots.ps1
	    Simple script to retrieve a screenshot of a virtual server.
    .DESCRIPTION
	    Simple script that accepts input from parameter or the pipeline and will 
	    start up a web page with a screenshot of the console page for the specified
	    virtual machines.  
	
	    This is a capability already present in VMware vSphere 5 and this script 
	    just simplifies getting the proper information.  
	
	    Requirments:  VMware vSphere 5 or greater
	                  VMware PowerCLI
				  
	    Don't forget to edit the PARAM section (specifically $VMHost) to match
	    your environment.
	
	    Special Thanks to Hubba Bubba at Spiceworks for testing this for me.
    .PARAMETER Name
	    Name, or names for the virtual servers you wish to view.  Accepts input
	    from the pipeline or it will prompt you.  Can be many servers.
    .PARAMETER VMHost
	    Name of your vCenter server, or the vSphere host server.  
    .EXAMPLE .\Get-VMScreenshots.ps1 -Name myvm -VMHost myvCenter
	    Will open your default browser and show the current console screen for "myvm".
    .EXAMPLE Get-Content Servers.txt | .\Get-VMScreenshots.ps1
	    Will pull each server name out of Servers.txt and display the screen shot
	    for those VM's.
    .EXAMPLE Get-VM *TEST* | .\Get-VMScreenshots.ps1
	    Will execute the Get-VM cmdlet, searching for all VM's with TEST in their
	    names and display those screen shots.
    .NOTES
	    Author:         Martin Pugh
	    Twitter:        @thesurlyadm1n
	    Spiceworks:     Martin9700
	    Blog:           www.thesurlyadmin.com
	
	    Changelog:
		    1.0         Initial release
    .LINK
	
    .LINK
	    http://www.youtube.com/watch?v=flo0bMs6hjY
    #>
    Param (
	    [Parameter(Mandatory=$true,
		    ValueFromPipeline=$true,
		    ValueFromPipelineByPropertyName=$true)]
	    [String[]]$Name,
	    [string]$VMHost = "vCenterServer"
    )

    Begin {
	    #Load VMWare CLI cmdlets
	    Try	{ 
		    If (-not (Get-PSSnapin VMware.VimAutomation.Core))
		    {	Add-PSSnapin VMware.VimAutomation.Core -ErrorAction Stop 
		    }
	    }
	    Catch { 
		    Write-Host "`n`nUnable to load VMware CLI cmdlets, are they installed on this host?"; Break 
	    }
	    #Now connect to vCenter using your credentials
	    Connect-VIServer $VMHost -ErrorAction Stop
    }

    Process {
	    Foreach ($VM in $Name)
	    {	$MoRef = (Get-VM $VM).ExtensionData.MoRef.Value
		    Start-Process -FilePath "https://$VMHost/screen?id=$MoRef"
	    }
    }
}

Get-VMScreenShot -Name testmlp101 -VMHost vcenter102
