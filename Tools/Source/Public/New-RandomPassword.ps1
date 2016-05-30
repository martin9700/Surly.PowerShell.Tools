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