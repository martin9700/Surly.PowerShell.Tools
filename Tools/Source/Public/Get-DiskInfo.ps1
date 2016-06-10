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
    #requires -version 2.0
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

#Get-DiskInfo -ComputerName corpbatch101 | fl *
