Function Compare-ADGroupMember {
<#
#>
    Param (
        [string]$GroupName = "APP_RMS*"
    )

    $GroupStatePath = Join-Path -Path (Split-Path $MyInvocation.MyCommand.Path) -ChildPath "GroupState.xml"

    $NowGroups = @{}
    ForEach ($Group in (Get-ADGroup -Filter {Name -like $GroupName} -Properties Member))
    {   $NowGroups.Add($Group.Name,$Group.Member)
    }

    If (Test-Path $GroupStatePath)
    {   $ThenGroups = Import-Clixml $GroupStatePath
        [PSCustomObject[]]$Changes = ForEach ($Group in $NowGroups.GetEnumerator())
        {   If ($ThenGroups.ContainsKey($Group.Name))
            {   ForEach ($Change in (Compare-Object -ReferenceObject $ThenGroups[$Group.Name] -DifferenceObject $Group.Value))
                {   $Line = $Change.InputObject
                    If ($Change.SideIndicator -eq "=>")
                    {   $Status = "Member Added"
                    }
                    Else
                    {   $Status = "Member Removed"
                    }
                    [PSCustomObject]@{
                        Change = $Status
                        Group = $Group.Name
                        User = $Line
                    }
                }
            }
            Else
            {   [PSCustomObject]@{
                    Change = "Group Added"
                    Group = $Group.Name
                    User = ""
                }
            }
        }
        If ($ThenGroups.Count -gt $NowGroups.Count)
        {   $Ref = [String[]]$ThenGroups.Keys
            $Diff = [String[]]$NowGroups.Keys
            $Changes += ForEach ($Change in (Compare-Object -ReferenceObject $Ref -DifferenceObject $Diff | Where SideIndicator -EQ "<="))
            {   [PSCustomObject]@{
                    Change = "Group Deleted"
                    Group = $Change.InputObject
                    User = ""
                }
            }
        }
    }

    $NowGroups | Export-Clixml $GroupStatePath
    Write-Output $Changes
}