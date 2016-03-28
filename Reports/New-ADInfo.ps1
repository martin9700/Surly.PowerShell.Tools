
<#
#>
[CmdletBinding()]
Param (
    [string]$Path
)

#Region Functions
#Set Alternating Rows in HTML tables
Function Set-AlternatingRows {
    [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
            [object[]]$HTMLDocument,
      
            [Parameter(Mandatory=$True)]
            [string]$CSSEvenClass,
      
            [Parameter(Mandatory=$True)]
            [string]$CSSOddClass
        )
        Begin {
            $ClassName = $CSSEvenClass
        }
        Process {
            [string]$Line = $HTMLDocument
            If ($Line.Contains("<tr>"))
            {    
                $Line = $Line.Replace("<tr>","<tr class=""$ClassName"">")
                If ($ClassName -eq $CSSEvenClass)
                {     $ClassName = $CSSOddClass
                }
                Else
                {     $ClassName = $CSSEvenClass
                }
            }
            $Line = $Line.Replace("[return]","<br>")
            Return $Line
        }
} #End Set-AlternatingRows

Function ConvertTo-OrderedList
{   Param (
        [array]$List
    )
    
    $Fragment = "<ul>"
    ForEach ($Line in $List)
    {   $Fragment += "<li>$Line</li>`n"
    }
    $Fragment += "</ul>"
    Return $Fragment
} #End ConvertTo-OrderedList
#endregion

If (-not $Path)
{
    $Path = Split-Path $Script:MyInvocation.MyCommand.Path
}
ElseIf (-not (Test-Path $Path))
{
    Throw "Path provided for report is not valid: $Path"
}


#Get AD Information
$WSHNetwork = New-Object -ComObject "Wscript.Network"
$Domain = $WSHNetwork.UserDomain
$Root = [ADSI] "LDAP://RootDSE"
$Config = $Root.ConfigurationNamingContext

#Get Sites
$SitesDN = "LDAP://CN=Sites,$Config"
$Sites = ForEach ($Site in ($([ADSI]$sitesDN).PSBase.Children | Where { $_.objectClass -eq "site" }))
{   $Site.Name
}

#Get Domain Controllers and Global Catalogs
$DomainControllers = @()
$DomainControllersSites = @()
$GC = @()
$DCs = ([System.DirectoryServices.ActiveDirectory.DomainController]::FindAll((New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("Domain",$Domain))))
ForEach ($DC in $DCs)
{   ForEach ($Role in $DC.Roles)
    {   Switch ($Role)
        {   "SchemaRole" {$FSMOSchema = $DC.Name}
            "NamingRole" {$FSMONaming = $DC.Name}
            "PdcRole" {$FSMOPDC = $DC.Name}
            "RidRole" {$FSMORID = $DC.Name}
            "InfrastructureRole" {$FSMOInfrastructure = $DC.Name}
        }
    }
    $DomainControllers += $DC.Name
    $DomainControllersSites += $DC.SiteName
    If ($DC.IsGlobalCatalog())
    {   $GC += $DC.Name
    }
}
$ActiveDirectory = New-Object PSObject -Property @{
    Domain = $Domain
    Sites = $Sites
    'Domain Controllers' = $DomainControllers
    'DC Site' = $DomainControllersSites
    'Global Catalogs' = $GC
    'Forest Schema Master' = $FSMOSchema
    'Forest Naming Master' = $FSMONaming
    'Domain PDC Emulator' = $FSMOPDC
    'Domain RID Master' = $FSMORID
    'Domain Infrastructure Master' = $FSMOInfrastructure
}
$DCs = @()
For ($i = 0; $i -lt $DomainControllers.Count; $i ++ )
{   $DCs += New-Object PSObject -Property @{
        Name = $DomainControllers[$i]
        Site = $DomainControllersSites[$i]
        'IP Address' = (Test-Connection $DomainControllers[$i] -Count 1).IPv4Address.IPAddressToString
    }
}
#Build the HTML
$SiteFragment = ConvertTo-OrderedList ($Sites | Sort) 
$DCFragment = $DCs | Select Name,Site,'IP Address' | Sort Site,Name | ConvertTo-Html -Fragment | Set-AlternatingRows -CSSEvenClass even -CSSOddClass odd
$GCFragment = ConvertTo-OrderedList ($GC | Sort)

$Body = @"
<html>
<head>
<style type='text/css'>
body {background-color:#DCDCDC;font-size:20px;}
b {font-size:24px;}
TABLE {border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;font-size:20px;}
TH {border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color: #6495ED;width:300px;}
TD {border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
</style>
<title>
Active Directory Information for $Company
</title>
</head>
<body>
<h2>Active Directory Information</h2>
<br>
<b>Domain Name:</b> $domain<br>
<br>
<p><b>AD Sites</b>
$SiteFragment
<br>
<b>Domain Controllers</b><p>
$DCFragment
<br>
<br>
<b>FSMO Role Holders</b><p>
<table>
<th>Role</th><th>Holder</th>
<tr><td>Forest-wide Schema Master</td><td>$FSMOSchema</td>
<tr><td>Forest-wide Domain Naming Master</td><td>$FSMONaming</td>
<tr><td>Domain's PDC Emulator</td><td>$FSMOPDC</td>
<tr><td>Domain's RID Master</td><td>$FSMORID</td>
<tr><td>Domain's Infrastructure Master</td><td>$FSMOInfrastructure</td>
</table>
<br>
<br>
<b>Global Catalogs</b>
$GCFragment
</body>
</html>
"@

$HTMLPath = Join-Path -Path $Path -ChildPath "ActiveDirectoryReport-$(Get-Date -Format 'MM-dd-yyyy').html"
$Body | Out-File $HTMLPath -Encoding ascii
& $HTMLPath
