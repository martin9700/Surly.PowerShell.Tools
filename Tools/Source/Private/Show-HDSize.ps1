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