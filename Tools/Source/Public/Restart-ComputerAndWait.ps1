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
                            Write-Error "$Computer has failed to reboot for 10 minutes, aborting script" -ErrorAction Stop
                        }

                        Try {
                            $CurrentBoot = Get-Uptime -Name $Computer -ErrorAction Stop
                        }
                        Catch {
                            $Retries ++
                            Start-Sleep -Seconds 20
                            Continue
                        }

                        If ($CurrentBoot.RebootSince.TotalSeconds -ge 60 -and $CurrentBoot.RebootSince.TotalSeconds -lt 600)
                        {
                            Write-Verbose "$Computer successfully rebooted" -Verbose
                            $Computers[$Computer].ThisReboot = $CurrentBoot.LastBootTime
                            Break
                        }
                        Write-Verbose "Waiting 20 seconds for $Computer" -Verbose
                        Start-Sleep -Seconds 20
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
                $Computer | Wait-Reboot
            }
        }

        If (-not $Wait)
        {
            $Keys | Wait-Reboot
        }

        Return $Computers.Values

        Write-Verbose "$(Get-Date): Restart-ComputerAndWait completed"
    }
}

"dbtest101b","dbtest401c" | Restart-ComputerAndWait
#Restart-ComputerAndWait -Name blahblah -ErrorAction Stop