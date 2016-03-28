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
        .\Get-DiskSize.ps1 -ComputerName Server1
        
        Get disk information for Server1
    .EXAMPLE
        .\Get-DiskSize.ps1 -ComputerName Server1,Server2 | Select Computer,Drive,FreeMB
        
        Get disk information for Server1 and Server2, but only display computer name, 
        drive letter and free space in MB
    .EXAMPLE
        .\Get-DiskSize.ps1 -ComputerName Server3 -ShowAll
        
        Get disk information for Server3, display all properties
    .EXAMPLE
        Get-Content c:\scripts\servers.txt | .\Get-DiskSize.ps1 | Sort Computer,Drive | Format-Table
        
        Retrieve all server names from Servers.txt and get disk information.  Sort 
        that information by Computer name and Drive letter and then send to Format-
        Table.  
    .NOTES
        Author:         Martin Pugh
        Twitter:        @thesurlyadm1n
        Spiceworks:     Martin9700
        Blog:           www.thesurlyadmin.com
           
        Changelog:
            1.1         Added % Used and % Free properties
            1.0         Initial Release
    .LINK
        http://community.spiceworks.com/scripts/show/2147-get-diskinfo
    #>
    #requires -version 2.0
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline=$true)]
        [String[]]$ComputerName = $env:COMPUTERNAME,
        [switch]$ShowAll
    )
    Begin {
        $DiskResults = @()
    }

    Process {
        ForEach ($Computer in $ComputerName)
        {   #Figure out how we're going to get the information.  PowerShell 2.0 does not support CIM so have to use
            #WMI.  PowerShell 3.0 supports CIM but not all servers support the WSMAN protocol.  So try that protocol
            #first (much faster) and if that doesn't work try DCOM.
            If ($PSVersionTable.PSVersion.Major -gt 2)
            {   Try {
                    Write-Verbose "$($Computer): Attempting to connect using WSMAN..."
                    $CimSession = New-CimSession -ComputerName $Computer -ErrorAction Stop
                }
                Catch {
                    Write-Verbose "$($Computer): Unable to connect with WSMAN"
                    Write-Verbose "$($Computer): Attempting to connect with DCOM..."
                    $CimSession = New-CimSession -ComputerName $Computer -SessionOption (New-CimSessionOption -Protocol Dcom) -ErrorAction SilentlyContinue -ErrorVariable EV
                }
                If ($CimSession)
                {   Write-Verbose "$($Computer): Successfully connected using $($CimSession.Protocol)"
                    Try {
                        $Disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType = 3" -CimSession $CimSession -ErrorAction Stop
                    }
                    Catch {
                        Write-Warning "$($Computer): Unable to connect to computer because ""$($Error[0])"""
                        Continue
                    }
                }
                Else
                {   Write-Warning "$($Computer): Unable to connect to computer because ""$($Error[0])"""
                    Continue
                }
            }
            Else
            {   Write-Verbose "$($Computer): Powershell 2.0 or older detected on host, attempting to connect with WMI..."
                Try {
                    $Disks = Get-WmiObject Win32_LogicalDisk -ComputerName $Computer -Filter "DriveType = 3" -ErrorAction Stop
                }
                Catch {
                    Write-Warning "$($Computer): Unable to connect to $Computer because ""$($Error[0])"""
                    Continue
                }
            }
        
            ForEach ($Disk in $Disks)
            {   $DiskResults += New-Object PSObject -Property @{
                    Computer = $Computer
                    Drive = $Disk.DeviceID
                    CapacityGB = "{0:N2}" -f ($Disk.Size / 1gb)
                    CapacityMB = "{0:N2}" -f ($Disk.Size / 1mb)
                    CapacityRaw = $Disk.Size
                    UsedGB = "{0:N2}" -f (($Disk.Size - $Disk.FreeSpace) / 1gb)
                    UsedMB = "{0:N2}" -f (($Disk.Size - $Disk.FreeSpace) / 1mb)
                    UsedPercent = "{0:P0}" -f (($Disk.Size - $Disk.FreeSpace) / $Disk.Size)
                    UsedRaw = ($Disk.Size - $Disk.FreeSpace)
                    FreeGB = "{0:N2}" -f ($Disk.FreeSpace / 1gb)
                    FreeMB = "{0:N2}" -f ($Disk.FreeSpace / 1mb)
                    FreePercent = "{0:P0}" -f ($Disk.FreeSpace / $Disk.Size)
                    FreeRaw = $Disk.FreeSpace
                    VolumeName = $Disk.VolumeName
                }
            }
        
        }
    }

    End {
        $DiskResults = $DiskResults | Select Computer,Drive,VolumeName,CapacityGB,CapacityMB,CapacityRAW,UsedGB,UsedMB,UsedRaw,UsedPercent,FreeGB,FreeMB,FreeRaw,FreePercent
        If (-not $ShowAll)
        {   #PowerShell 3.0 only, set a default view of only a few items.  
            $DiskResults | Add-Member MemberSet PSStandardMembers ([System.Management.Automation.PSMemberInfo[]]@(New-Object System.Management.Automation.PSPropertySet("DefaultDisplayPropertySet",[String[]]@("Computer","Drive","CapacityGB","UsedGB","FreeGB"))))
        }

        $DiskResults
    }
}

Get-DiskInfo -ComputerName bfd-faxrptsql1 -Verbose
