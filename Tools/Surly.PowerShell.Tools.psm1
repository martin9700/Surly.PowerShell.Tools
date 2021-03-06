Function Show-HDSize {
    #Return disk size converted to closest size
    Param (
        [Parameter(ValueFromPipeline=$true)]
        [int64]$Size
    )

    Process {
        If ($Size -gt 1125899906842624)
        {
            $Result = "{0:N2} PB" -f ($Size / 1PB)
        }
        ElseIf ($Size -gt 1099511627776)
        {
            $Result = "{0:N2} TB" -f ($Size / 1TB)
        }
        ElseIf ($Size -gt 1073741824)
        {
            $Result = "{0:N2} GB" -f ($Size / 1GB)
        }
        Else
        {
            $Result = "{0:N2} MB" -f ($Size / 1MB)
        }
        Return $Result
    }
}


Function Compare-ADGroupMember {
<#
    .SYNOPSIS
        This function will allow you to monitor if a group has changed. You can monitor multiple groups.
    .DESCRIPTION
        Function saves a copy of the group when you first run it.  The next time you run the function it will
        compare the members of the group that are there now to what was there previously and report any 
        differences.

    .PARAMETER Name
        Name of the group or groups you want to "watch".  
    .PARAMETER Path
        Path to where the script will save groupstate.xml, which is the past membership of all the groups.
    .INPUTS
        None
    .OUTPUTS
        PSCustomObject
    .EXAMPLE
        Compare-ADGroupMember -Name Group1,Group2

    .EXAMPLE
        Compare-ADGroupMember -Name Group2 -Path c:\path

    .NOTES
        Author:             Martin Pugh
        Twitter:            @thesurlyadm1n
        Spiceworks:         Martin9700
        Blog:               www.thesurlyadmin.com
      
        Changelog:
            2.0             Complete rewrite of the function.  Should be much more efficient and easy to maintain.  Added
                            comment based help.  
            1.0             Initial Release
    .LINK
    
#>
    [CmdletBinding()]
    Param (
        
        [string[]]$Name,
        [string]$Path = $env:TEMP
    )

    If (-not (Test-Path $Path))
    {
        Throw "The path ""$Path"" cannot be found.  This path is used for saving the past group memberships and is required."
    }
    $GroupStatePath = Join-Path -Path $Path -ChildPath "GroupState.xml"

    If (Test-Path $GroupStatePath)
    {   
        $ThenGroups = Import-Clixml $GroupStatePath
    }
    Else
    {
        $ThenGroups = @{}
    }

    $NowGroups = @{}
    Write-Verbose "Getting group memberships for $($Name -join ', ')..."
    [PSCustomObject[]]$Changes = ForEach ($Group in $Name)
    {
        Try {
            $NowGroups.Add($Group,(Get-ADGroup $Group -Properties Member | Select -ExpandProperty Member))
        }
        Catch {
            Write-Warning "Unable to locate group: $Group"
            If ($ThenGroups.Keys -contains $Group)
            {
                [PSCustomObject]@{
                    Change = "Group deleted"
                    Group = $Group
                    UserName = ""
                    Sort = 0
                }
            }
            Continue
        }
        If ($ThenGroups.Keys -contains $Group)
        {
            ForEach ($Change in (Compare-Object -ReferenceObject $ThenGroups[$Group] -DifferenceObject $NowGroups[$Group]))
            {   
                If ($Change.SideIndicator -eq "=>")
                {   $Status = "Added"
                }
                Else
                {   $Status = "Removed"
                }
                [PSCustomObject]@{
                    Change = $Status
                    Group = $Group
                    UserName = Get-ADUser $Change.InputObject | Select -ExpandProperty SamAccountName
                    Sort = 1
                }
            }
        }
        Else
        {
            [PSCustomObject]@{
                Change = "Group added to watch"
                Group = $Group
                UserName = ""
                Sort = 0
            }
        }
    }

    [PSCustomObject[]]$Changes += ForEach ($Group in $ThenGroups.Keys)
    {
        If ($Name -notcontains $Group)
        {
            [PSCustomObject]@{
                Change = "Group removed from watch"
                Group = $Group
                UserName = ""
                Sort = 0
            }
        }
    }

    $NowGroups | Export-Clixml $GroupStatePath
    If (-not $Changes)
    {
        Write-Verbose "No changes in the groups ""$($Name -join ' ,')"" detected."
    }
    Return $Changes | Sort Sort | Select Change,Group,UserName
}


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


Function Get-ComputerInfo {
    <#
    .SYNOPSIS
        Get basic information for a computer
    .DESCRIPTION
        Get's basic information about a computer, like IP address, Make/Model, CPU, disk space, etc.

        Leverages Get-DiskInfo function.

        ** Requires AH.Automation Function **
    .PARAMETER Name
        Name or names of the computers you wish to get the information about.
    .INPUTS
        Microsoft.ActiveDirectory.Management.ADComputer
    .OUTPUTS
        System.Management.Automation.PSCustomObject 
    .EXAMPLE
        Get-ComputerInfo -ComputerName opsadmin101
    .EXAMPLE
        $DocTrans = 1..5 | ForEach { "doctransa10$_" }
        Get-ComputerInfo -ComputerName $DocTrans
    .EXAMPLE
        Add-PSSNapin VMware.VIMAutomation.Core
        Connect-VIServer vcenter101
        Get-Folder "A Environment" | Get-VM | Get-ComputerInfo

        Get computer information for all servers in Bedford and Belfast "A" faxing environments
    .EXAMPLE
        Get-ADComputer -Filter {Name -like "*db*"} | Get-ComputerInfo

        Get computer information for all servers in Active Directory that have the letters "db" in them.
    .NOTES
        Author:             Martin Pugh
        Date:               2/15/2016
      
        Changelog:
            01/15           MLP - Initial Release
            02/16           MLP - Added error capture on first WMI call so if there is a failure it won't keep trying.  Added pipeline support.  Added comment based help.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [Alias("ComputerName")]
        [string[]]$Name = $env:COMPUTERNAME
    )

    PROCESS {
        ForEach ($Computer in $Name)
        {
            If (Test-Connection $Computer -Count 1 -Quiet)
            {
                If ($Computer -match "\d+\.\d+\.\d+\.\d+")
                {
                    $IP = $Computer
                    $Computer = ([System.Net.Dns]::GetHostByAddress($Computer)).HostName
                }
                Else
                {
                    $IP = [System.Net.Dns]::GetHostEntry($Computer) | Select -ExpandProperty AddressList
                }
                Try {
                    $WMI = Get-WmiObject -ComputerName $Computer -Class Win32_ComputerSystem -ErrorAction Stop
                }
                Catch {
                    Write-Error "$(Get-Date): Unable to contact $Computer over WMI"
                    Continue
                }
                $Uptime = Get-Uptime -Name $Computer
                $Result = [PSCustomObject]@{
                    Name = $Computer
                    Domain = $WMI.Domain
                    IP = $IP
                    OS = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $Computer | Select -ExpandProperty Caption
                    Make = $WMI.Manufacturer
                    Model = $WMI.Model
                    CPU = @(Get-WmiObject -Class Win32_Processor -ComputerName $Computer).Count
                    RAM = [math]::Round($WMI.TotalPhysicalMemory / 1gb)
                    Uptime = $Uptime.RebootSince
                    LastReboot = $Uptime.LastBootTime
                }

                $Disks = Get-DiskInfo -ComputerName $Computer
                ForEach ($Disk in $Disks)
                {
                    $Result | Add-Member -MemberType NoteProperty -Name $Disk.Drive -Value ("$($Disk.UsedGB)GB of $($Disk.CapacityGB)GB ({0:N2}GB, $($Disk.FreePercent.Replace(' ','')) Free) ($($Disk.Disk.Replace('\\.\','')) $($Disk.VolumeName))" -f ($Disk.CapacityGB - $Disk.UsedGB))
                }

                Write-Output $Result
            }
        }
    }
}


Function Get-DiskInfo
{   <#
    .SYNOPSIS
        Simple tool to get disk information for a computer
    .DESCRIPTION
        The purpose of this script is to give the Windows Administrator a simple, fast
        tool for viewing disk information for a computer or group of computers.
        
        For PowerShell 3.0 or higher users, only some properties are displayed by
        default.  If you want to see more or different values you can use Select.
        PowerShell 2.0 users will see all values.
    .PARAMETER ComputerName
        List of computers that you want to get disk information for.
    .PARAMETER ShowAll
        Use this parameter to have script show all properties
    .INPUTS
        Text
    .OUTPUTS
        Custom PS Object
            Computer*
            Drive*
            CapacityGB*
            CapacityMB
            CapacityRaw
            UsedGB*
            UsedMB
            UsedRaw
            UsedPercent
            FreeGB*
            FreeMB
            FreeRaw
            FreePercent
            VolumeName
            
            * In default view
    .EXAMPLE
        Get-DiskSize -ComputerName Server1
        
        Get disk information for Server1
    .EXAMPLE
        Get-DiskSize -ComputerName Server1,Server2 | Select Computer,Drive,FreeMB
        
        Get disk information for Server1 and Server2, but only display computer name, 
        drive letter and free space in MB
    .EXAMPLE
        Get-DiskSize -ComputerName Server3 -ShowAll
        
        Get disk information for Server3, display all properties
    .EXAMPLE
        Get-Content c:\scripts\servers.txt | Get-DiskSize | Sort Computer,Drive | Format-Table
        
        Retrieve all server names from Servers.txt and get disk information.  Sort 
        that information by Computer name and Drive letter and then send to Format-
        Table.  
    .NOTES
        Author:         Martin Pugh
        Twitter:        @thesurlyadm1n
        Spiceworks:     Martin9700
        Blog:           www.thesurlyadmin.com
           
        Changelog:
            1.0         Initial Release
            1.1         Added % Used and % Free properties
            2.0         Full rewrite: added pipeline from Get-ADcomputer, using Get-WQLQuery function, all new
                        WQL queries to get physical disk, partition and drive information, using Show-HDSize
                        private function for human readable output, using [PSCustomObject] output
    .LINK
        http://community.spiceworks.com/scripts/show/2147-get-diskinfo
    #>
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [Alias("ComputerName")]
        [String[]]$Name = $env:COMPUTERNAME,
        [switch]$ShowAll
    )
    Begin {
        $DiskResults = @()
    }

    Process {
        $DiskResults += ForEach ($Computer in $Name)
        {   
            ForEach ($Disk in (Get-WQLQuery -Name $Computer -Query "SELECT DeviceID,Size,Model FROM Win32_DiskDrive" | Sort DeviceID))
            {
                ForEach ($Partition in (Get-WQLQuery -Name $Computer -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($Disk.DeviceID)'} WHERE AssocClass = Win32_DiskDriveToDiskPartition"))
                {
                    ForEach ($Drive in (Get-WQLQuery -Name $Computer -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($Partition.DeviceID)'} WHERE AssocClass = Win32_LogicalDiskToPartition"))
                    {
                        [PSCustomObject]@{
                            Computer = $Computer
                            Disk = $Disk.DeviceID
                            DiskSize = $Disk.Size | Show-HDSize
                            DiskModel = $Disk.Model
                            Partition = $Partition.Name
                            PartitionRawSize = $Partition.Size | Show-HDSize
                            Drive = $Drive.DeviceID
                            VolumeName = $Drive.VolumeName
                            CapacityGB = "{0:N2}" -f ($Drive.Size / 1gb)
                            CapacityMB = "{0:N2}" -f ($Drive.Size / 1mb)
                            CapacityRaw = $Drive.Size
                            UsedGB = "{0:N2}" -f (($Drive.Size - $Drive.FreeSpace) / 1gb)
                            UsedMB = "{0:N2}" -f (($Drive.Size - $Drive.FreeSpace) / 1mb)
                            UsedPercent = "{0:P0}" -f (($Drive.Size - $Drive.FreeSpace) / $Drive.Size)
                            UsedRaw = ($Drive.Size - $Drive.FreeSpace)
                            FreeGB = "{0:N2}" -f ($Drive.FreeSpace / 1gb)
                            FreeMB = "{0:N2}" -f ($Drive.FreeSpace / 1mb)
                            FreePercent = "{0:P0}" -f ($Drive.FreeSpace / $Drive.Size)
                            FreeRaw = $Drive.FreeSpace
                        }
                    }
                }
            }
        }
    }

    End {
        If (-not $ShowAll)
        {   #PowerShell 3.0 only, set a default view of only a few items.  
            $DiskResults | Add-Member MemberSet PSStandardMembers ([System.Management.Automation.PSMemberInfo[]]@(New-Object System.Management.Automation.PSPropertySet("DefaultDisplayPropertySet",[String[]]@("Computer","Drive","CapacityGB","UsedGB","FreeGB"))))
        }

        Return $DiskResults
    }
}


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
        #Thanks to CosmosKey (wherever you are!) at Superuser.com for this solution
        $TextBox = New-Object System.Windows.Forms.TextBox
        $TextBox.Multiline = $true
        $TextBox.Text = $Result.distinguishedName
        $TextBox.SelectAll()
        $TextBox.Copy()
        $TextBox.Dispose()
	}
}


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
            2.1             Changed to use Get-CimInstance.  Added position parameter decorations for more intuitive use.  Why no try/catch?  
                            The built in messsage from Get-CimInstance is pretty good, and I couldn't see a way to improve on it.  Ain't broke!
	.LINK
		http://www.thesurlyadmin.com/2012/09/06/get-service-information-for-a-list-of-computers
    .LINK
		http://community.spiceworks.com/scripts/show/1639-get-serviceinformation-extended
	#>
    [CmdletBinding()]
	Param(
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName,Position=1)]
        [Alias("ComputerName")]
		[string[]]$Name = $env:computername,
        [Parameter(Position=0)]
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

                Get-CimInstance @CimParams | Select @{Name="ComputerName";Expression={$Computer}},DisplayName,Name,StartMode,@{Name="ServiceLogon";Expression={$_.StartName}},State
            }
        }
    }
    End
	{
        Write-Verbose "$(Get-Date): Get-ServiceInfo completed"
	}
}


Function Get-Uptime {
    <#
    .SYNOPSIS
        Get's uptime for a server
    .DESCRIPTION
        Retrieve uptime information for a server or servers.  Input can come from text files, input or
        cmdlet.
    .PARAMETER Name
        Name of the computer you want to get the uptime information from
    .INPUTS
        Name property
    .OUTPUTS
        PSCustomObject
            Name                [string]
            LastBootTime        [datetime]
            RebootSince         [timespan]
        
    .EXAMPLE
        .\Get-Uptime.ps1 -Name corpdc101
    
        Retrieve the uptime informatoin for corpdc101
    
    .EXAMPLE
        .\Get-Uptime.ps1 -Name (Get-Content .\servers.txt)
        Get-Content .\servers.txt | .\Get-Uptime.ps1
    
        Get uptime information for all the servers listed in servers.txt
    
    .EXAMPLE
        Get-ADComputer -Filter {name -like *DC*} | .\Get-Uptime.ps1
    
        Get uptime information for all computers in the domain that have DC in them somewhere.
    
    .NOTES
        Author:             Martin Pugh
        Date:               9/19/2014
      
        Changelog:
            9/19/14         MLP - Initial Release
            7/17/15         MLP - Added default to local computer
            4/17/16         MLP - Changed to using Get-CimInstance, changed to PSCustomObject and updated LastBootUpTime which is now a 
                                  date/time object instead of FileTime
    .LINK
        https://github.com/martin9700/Surly.PowerShell.Tools
    #>
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [Alias("ComputerName")]
	    [string[]]$Name = $env:COMPUTERNAME
    )
    Process {
        ForEach ($Computer in $Name)
        {   Write-Verbose "Checking Host: $Computer"
            Try {
                #LastBootUpTime
                $LastBoot = Get-WQLQuery -ComputerName $Computer -Query "SELECT LastBootUpTime FROM Win32_OperatingSystem" -ErrorAction Stop
            }
            Catch {
                Write-Error "Unable to get LastBootTime from $Computer because ""$($_)"""
                Continue
            }
            If ($LastBoot.WMIProtocol -eq "WSMAN") 
            { 
                $LBT = $LastBoot.LastBootUpTime 
            } 
            Else 
            { 
                $LBT = $Lastboot.ConvertToDateTime($LastBoot.LastBootUpTime)
            }
            
            [PSCustomObject]@{
                Name = $Computer
                LastBootTime = $LBT
                RebootSince = New-TimeSpan -Start $LBT -End (Get-Date)
            }
        }
    }
}


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


Function New-RandomPassword
{   Param (
        [int]$Length = (Get-Random -Minimum 12 -Maximum 17)
    )
    
    $CharSet = [Char[]]"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()"
    $CharSet2 = [Char[]]"!@#$%^&*()!!!"
    $Password = (($CharSet | Get-Random -Count ($Length - 1)) -join "") + (($CharSet2 | Get-Random) -join "")
		[Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
        #Thanks to CosmosKey (wherever you are!) at Superuser.com for this solution
        $TextBox = New-Object System.Windows.Forms.TextBox
        $TextBox.Multiline = $false
        $TextBox.Text = $Password
        $TextBox.SelectAll()
        $TextBox.Copy()
        $TextBox.Dispose()

    Return $Password
}


Function Restart-ComputerAndWait {
    <#
    .SYNOPSIS
        Reboot a computer and properly wait until it has completed rebooting
    .DESCRIPTION
        This script is meant to fix the troubleshoot -Wait parameter in Restart-Computer.  It can reboot
        every specified computer and then it will wait for all of them to complete.  You can also specify
        that you want ot do this serially (restart one and wait, restart the next one and wait, etc.)



        ** Requires:
            Get-Uptime from Surly.PowerShell.Tools
            Get-WQLQuery from Surly.PowerShell.Tools
    .PARAMETER Name
        Name of the computer you want to reboot
    .PARAMETER Wait
        Requires the function to wait for one computer to complete the reboot cycle before moving on
        to the next
    .INPUTS
    .OUTPUTS
    .EXAMPLE
    .EXAMPLE
    .NOTES
        Author:             Martin Pugh
        Twitter:            @thesurlyadm1n
        Spiceworks:         Martin9700
        Blog:               www.thesurlyadmin.com
      
        Changelog:
            1.0             Initial Release
    .LINK
    
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [Alias("ComputerName")]
        [string[]]$Name,
        [switch]$Wait
    )

    Begin {
        Write-Verbose "$(Get-Date): Restart-ComputerAndWait begins"
        Write-Verbose "Gathering initial information" -Verbose
        $Computers = @{}

        Function Wait-Reboot {
            <#
            .SYNOPSIS
                Wait for computer reboot based on uptime
            .PARAMETER Timeout
                Number of minutes to wait on failed uptime requests before aborting
            #>
            Param (
                [Parameter(Mandatory=$true,
                    ValueFromPipeline=$true)]
                [string[]]$ComputerName,
                [int]$Timeout = 10
            )

            Begin {
                $FilterHash = @{
                    ID = 6005
                    StartTime = Get-Date
                    LogName = "System"
                }
                $MaxRetries = $Timeout * 3
                Start-Sleep -Seconds 20
            }

            Process {
                ForEach ($Computer in $ComputerName)
                {
                    $Retries = 0
                    Do {
                        If ($Retries -gt $MaxRetries)
                        {
                            Write-Error "$Computer has failed to reboot for $Timeout minutes, aborting script" -ErrorAction Stop
                        }

                        $UpYet = Get-WinEvent -ComputerName $Computer -FilterHashtable $FilterHash -ErrorAction SilentlyContinue
                        If ($UpYet)
                        {
                            $CurrentBoot = Get-Uptime -Name $Computer -ErrorAction Stop
                            If ($CurrentBoot.RebootSince.TotalSeconds -ge 60 -and $CurrentBoot.RebootSince.TotalSeconds -lt 600)
                            {
                                Write-Verbose "$Computer successfully rebooted" -Verbose
                                $Computers[$Computer].ThisReboot = $CurrentBoot.LastBootTime
                                Break
                            }
                            Write-Verbose "Waiting 20 seconds for $Computer" -Verbose
                            Start-Sleep -Seconds 20
                        }
                        Else
                        {
                            $Retries ++
                            Start-Sleep -Seconds 20
                            Continue
                        }
                    } While ($true)
                }
            }
        }
    }

    Process {
        ForEach ($Computer in $Name)
        {
            If (-not $Computers.ContainsKey($Computer))
            {
                Try {
                    $InitBoot = Get-Uptime -Name $Computer -ErrorAction Stop
                }
                Catch {
                    Write-Error "Unable to get initial boot time from $Computer because ""$_"""
                    Continue
                }
                $Computers.Add($Computer,[PSCustomObject]@{
                    Name = $Computer
                    PriorReboot = $InitBoot.LastBootTime
                    ThisReboot = ""
                })
            }
        }
    }

    End {
        #First reboot all computers specified
        [string[]]$Keys = $Computers.Keys
        ForEach ($Computer in $Keys)
        {
            Write-Verbose "Rebooting $Computer..." -Verbose
            Try {
                Restart-Computer -ComputerName $Computer -Confirm:$false -Force -ErrorAction Stop
            }
            Catch {
                Write-Error "Failed to restart $Computer because ""$_"""
                Continue
            }

            If ($Wait)
            {
                $Computer | Wait-Reboot -ErrorAction Stop
            }
        }

        If (-not $Wait)
        {
            $Keys | Wait-Reboot -ErrorAction Stop
        }

        Return $Computers.Values

        Write-Verbose "$(Get-Date): Restart-ComputerAndWait completed"
    }
}


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


#Included Statements:


