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
                    $Result | Add-Member -MemberType NoteProperty -Name $Disk.Drive -Value ("{0}GB of {1}GB ({2}GB, {3} Free)" -f $Disk.UsedGB,$Disk.CapacityGB,($Disk.CapacityGB - $Disk.UsedGB),$Disk.FreePercent.Replace(" ",""))
                }

                Write-Output $Result
            }
        }
    }
}

get-adcomputer -filter {enabled -eq $true} | Select -first 3 | get-computerinfo