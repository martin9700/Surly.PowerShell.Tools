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

#Compare-ADGroupMember -Name TestUserGroup -Verbose