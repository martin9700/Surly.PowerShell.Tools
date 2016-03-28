Function New-RandomPassword
{   Param (
        [int]$Length = (Get-Random -Minimum 12 -Maximum 17)
    )
    
    $CharSet = [Char[]]"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()"
    $CharSet2 = [Char[]]"!@#$%^&*()!!!"
    $Password = (($CharSet | Get-Random -Count ($Length - 1)) -join "") + (($CharSet2 | Get-Random) -join "")
    [Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    [Windows.Forms.Clipboard]::SetDataObject($Password, $true)

    Return $Password
}