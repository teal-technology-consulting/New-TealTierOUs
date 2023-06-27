<#
.SYNOPSIS
    This script creates Organisational Units required for the tiering model.
.DESCRIPTION
    This script uses XML-based configuration files where the OUs are defined. There is one configuration file for each tier, T0OU.xml, T1OU.xml and T2OU.xml.
.PARAMETER Path
    Species the path to the directorz in which the xml files are located. The default is the directory of the script.
.PARAMETER Tier
    Species which tier(s) to create. Valid values are "0", "1", "2", "all", "01", "02" and "12". The script will create the specified tiers or all three of them.
.EXAMPLE
    Invoke-OUAutomation.ps1 -Tier all
.NOTES
    The user can specify which tier(s) will be created. The XML files must be customized before using the script. 

    This script is published under the "MIT No Attribution License" (MIT-0) license.

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so.

    THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

#Requires -Version 3.0
#Requires -Modules ActiveDirectory

[CmdletBinding()]
Param (
    # Path to xml files
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateScript({Test-Path -Path $_ -PathType Container})]
    [string]$Path = $PSScriptRoot,

    # Specifies the Tier that will be created
    [Parameter(Mandatory = $true)]
    [ValidateSet("0", "1", "2", "all", "01", "02", "12")]
    [string]$Tier
)

Set-StrictMode -Version latest

If ($PSBoundParameters['Debug']) {
    $DebugPreference = 'Continue'
}

If ($PSBoundParameters['Verbose']) {
    $VerbosePreference = "Continue"
}

if ($PSScriptRoot.Length -eq 0) {
    $Scriptlocation = (get-location).path
}
else {
    $Scriptlocation = $PSScriptRoot
}


[string]$component = (Get-Item -Path $MyInvocation.MyCommand.Source).BaseName
[string]$Global:LogPath = $null
$Global:LogPath = $Scriptlocation
[string]$Global:LogFilePath = $null
$Global:LogfilePath = $(Join-Path -Path $Global:LogPath  -ChildPath "$($component).log")

function Write-Log {
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LogText,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string]$Component = '',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Type = 'Information',

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [int]$Thread = $PID,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string]$File = '',

        [Parameter(Mandatory = $false)]
        [int]$LogMaxSize = 5.0MB,

        [Parameter(Mandatory = $false)]
        [int]$LogMaxHistory = 5
    )
    
    Begin {
        switch ($Type) {
            'Information' { $TypeNum = 1 }
            'Warning' { $TypeNum = 2 }
            'Error' { $TypeNum = 3 }
        }
    
        if (-not $Global:LogFilePath) {
            Write-Error -Message 'Variable $LogFilePath not defined in scope $Global:'
            exit 1
        }
        
        if (-not (Test-Path -Path $Global:LogFilePath -PathType Leaf)) {
            New-Item -Path $Global:LogFilePath -ItemType File -ErrorAction Stop | Out-Null
        }
        
        $LogFile = Get-Item -Path $Global:LogFilePath
        if ($LogFile.Length -ge $LogMaxSize) {
            $NewFileName = "{0}-{1:yyyyMMdd-HHmmss}{2}" -f $LogFile.BaseName, $LogFile.LastWriteTime, $LogFile.Extension
            $LogFile | Rename-Item -NewName $NewFileName
            New-Item -Path $Global:LogFilePath -ItemType File -ErrorAction Stop | Out-Null

            $ArchiveLogFiles = Get-ChildItem -Path $LogFile.Directory -Filter "$($LogFile.BaseName)*.log" | Where-Object { $_.Name -match "$($LogFile.BaseName)-\d{8}-\d{6}\.log" } | Sort-Object -Property BaseName
            if ($ArchiveLogFiles) {
                if ($ArchiveLogFiles.Count -gt $LogMaxHistory) {
                    $ArchiveLogFiles | Sort-Object lastwritetime -Descending | Select-Object -Skip ($LogMaxHistory) | Remove-Item
                }
            }
        }
    }
    
    Process {
        $now = Get-Date
        $Bias = ($now.ToUniversalTime() - $now).TotalMinutes
        [string]$Line = "<![LOG[{0}]LOG]!><time=`"{1:HH:mm:ss.fff}{2}`" date=`"{1:MM-dd-yyyy}`" component=`"{3}`" context=`"`" type=`"{4}`" thread=`"{5}`" file=`"{6}`">" -f $LogText, $now, $Bias, $Component, $TypeNum, $Thread, $File
        $Line | Out-File -FilePath $Global:LogFilePath -Encoding utf8 -Append -ErrorAction Stop
        Write-Verbose $Line
    }
    
    End {
    }
}

function Add-TieringOU 
{
    <#
    .SYNOPSIS
        Creates a new Active Directory organizational unit.
    .DESCRIPTION
        creates an Active Directory organizational unit (OU). If the OU already exists, the OU will not be created.
    .PARAMETER OUName
        Specifies the name of the OU.
    .PARAMETER OUPath
        Specifies the X.500 path of the Organizational Unit (OU) or container where the new object is created.
    #>
    
    [CmdletBinding()]
    Param (
        # Name of the soon to be OU
        [Parameter(Mandatory = $true)]
        [string]$OUName,

        # Path to the soon to be OU
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$OUPath,
        
        [Parameter(Mandatory = $true)]
        [string]$DomainDN
    )

    # Checks if OU already exsists, if not creates it. Differentiates between Top Level OU and lower level OUs
    try {
        Write-Log -LogText "Check if OU: $OUName exists in path $OUPath" -Component $component -Type Information
        if (-not $OUPath) {
            $NewOU = "OU=$OUName,$DomainDN"
        }
        else {
            $NewOU = "OU=$OUName,$($OUPath + "," + $DomainDN)"
        }
    
        if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$NewOU'") {
            Write-Log -LogText "OU exists: $NewOU" -Component $component -Type Information
            Write-Verbose -Message "OU exists: $NewOU"
            $result = $NewOU
        }
        else {
            Write-Log -LogText "Create OU: $OUName" -Component $component -Type Information
            Write-Verbose -Message "Create OU: $OUName"
            if (-not $OUPath) {
                Write-Log -LogText "OU Path in which the OU get created: $DomainDN" -Component $component -Type Information
                Write-Verbose -Message "OU Path in which the OU get created: $DomainDN"
                $result = (New-ADOrganizationalUnit -Name $OUName -Path $DomainDN -PassThru).DistinguishedName
                Write-Log -LogText "OU successfully created: $result" -Component $component -Type Information
                Write-Verbose -Message "OU successfully created: $result"
            }
            else {
                Write-Log -LogText "OU Path in which the OU get created: $($OUPath + "," + $DomainDN)" -Component $component -Type Information
                Write-Verbose -Message "OU Path in which the OU get created: $($OUPath + "," + $DomainDN)"
                $result = (New-ADOrganizationalUnit -Name $OUName -Path $($OUPath + "," + $DomainDN) -PassThru).DistinguishedName
                Write-Log -LogText "OU successfully created: $result" -Component $component -Type Information
                Write-Verbose -Message "OU successfully created: $result"
            }
        }
    }
    catch {
        write-log -LogText $_ -Component $component -Type Error
        write-log -LogText "Error in script line: $($_.InvocationInfo.ScriptLineNumber)" -Component $component -Type Error
        Write-Error $_
        Exit 99
    }
    Write-Output $result
}

function Invoke-Level 
{
    <#
    .SYNOPSIS
        This functions purpose is level control
    .DESCRIPTION
        This function is called by Invoke-Tiering and calls Add-TieringOU while making sure, that Add-TieringOU creates the OU in the correct level order
    .PARAMETER TierOU
        TierOU is the array read from the corresponding tier xml file
    .PARAMETER DomainDN
    #>

    [CmdletBinding()]
    Param (
        # Path to xml files
        [Parameter(Mandatory = $true)]
        [array]
        $TierOU,

        [Parameter(Mandatory = $true)]
        [string]
        $DomainDN
    )
    try {
        for ($i = 0; $i -le 10; $i++) {
            foreach ($OUDefinition in $TierOU) {
                if ($OUDefinition.level -eq $i) {
                    foreach ($OU in $OUDefinition.OU) {
                        #OU Creation
                        Write-Log -LogText "Start OU Processing: $($OU.OUName)" -Component $component -Type Information
                        Write-Verbose -Message "Start OU Processing: $($OU.OUName)"
                        $OUDN = Add-TieringOU -OUName $OU.OUName -OUPath $OUDefinition.OUPath -DomainDN $DomainDN
                        Write-Log -LogText "Finished OU Processing. OU Distinguished Name: $OUDN" -Component $component -Type Information
                        Write-Verbose -Message "Finished OU Processing. OU Distinguished Name: $OUDN"
                    }
                }
            }
        }
    }
    catch {
        write-log -LogText $_ -Component $component -Type Error
        write-log -LogText "Error in script line: $($_.InvocationInfo.ScriptLineNumber)" -Component $component -Type Error
        Write-Error $_
    }
}

function Invoke-Tiering 
{
    <#
    .SYNOPSIS
        This function will create Organisational Units as needed for the tiering model and defined by the user
    .DESCRIPTION
        This function will take the entries from T0OU.xml, T1OU.xml, T2OU.xml and create the Organisational Units accordingly by calling Invoke-Level,
        which in turn calls Add-TieringOU.
        The parameters are directly forwarded from the user input.
    .PARAMETER Path
        Path describes the path to the folder in which the xml files reside. Default value is ".\"
    .PARAMETER Tier
        Tier tells the script, which tier to create. Valid values are "0","1","2","all","01","02" and "12". The script will create the specified tiers or all three of them.
    .PARAMETER DomainDN
    #>
    
    [CmdletBinding()]
    Param (
        # Path to xml files
        [Parameter(Mandatory = $true)]
        [string]$Path,

        # Specifies the Tier that will be created
        [Parameter(Mandatory = $true)]
        [ValidateSet("0", "1", "2", "all", "01", "02", "12")]
        [string]$Tier,

        [Parameter(Mandatory = $true)]
        [string]$DomainDN
    )
    
    #Get content of xml and create OU depending on selected tier for each level
    if ($Tier -eq "0" -or $Tier -eq "01" -or $Tier -eq "02" -or $Tier -eq "all") {
        Write-Log -LogText "Read config file: T0OU.xml" -Component $component -Type Information
        Write-Verbose -Message "Read config file: T0OU.xml"
        $FilePath = Join-Path -Path $Path -ChildPath "T0OU.xml"
        $Tier0OU = Select-Xml -Path $FilePath -XPath "Tiering/OUDefinition" | Select-Object -ExpandProperty Node
        Write-Log -LogText "Invoke tiering level: $Tier" -Component $component -Type Information
        Write-Verbose -Message "Invoke tiering level: $Tier"
        Invoke-Level -TierOU $Tier0OU -DomainDN $DomainDN
    }
    if ($Tier -eq "1" -or $Tier -eq "01" -or $Tier -eq "12" -or $Tier -eq "all") {
        Write-Log -LogText "Read config file: T1OU.xml" -Component $component -Type Information
        Write-Verbose -Message "Read config file: T1OU.xml"
        $FilePath = Join-Path -Path $Path -ChildPath "T1OU.xml"
        $Tier1OU = Select-Xml -Path $FilePath -XPath "Tiering/OUDefinition" | Select-Object -ExpandProperty Node
        Write-Log -LogText "Invoke tiering level: $Tier" -Component $component -Type Information
        Write-Verbose -Message "Invoke tiering level: $Tier"
        Invoke-Level -TierOU $Tier1OU -DomainDN $DomainDN
    }
    if ($Tier -eq "2" -or $Tier -eq "02" -or $Tier -eq "12" -or $Tier -eq "all") {
        Write-Log -LogText "Read config file: T2OU.xml" -Component $component -Type Information
        Write-Verbose -Message "Read config file: T2OU.xml"
        $FilePath = Join-Path -Path $Path -ChildPath "T2OU.xml"
        $Tier2OU = Select-Xml -Path $FilePath -XPath "Tiering/OUDefinition" | Select-Object -ExpandProperty Node
        Write-Log -LogText "Invoke tiering level: $Tier" -Component $component -Type Information
        Write-Verbose -Message "Invoke tiering level: $Tier"
        Invoke-Level -TierOU $Tier2OU -DomainDN $DomainDN
    }
}

Write-Log -LogText "Start Script:" -Component $component -Type Information
Write-Verbose -Message "Start Script:"

try {
    write-log -LogText "Get environment information: Domain, DistinguishedName and FSMO Infrastructure Master" -Component $component -Type Information
    Write-Verbose -Message "Get environment information: Domain, DistinguishedName and FSMO Infrastructure Master"
    [string]$DomainDN = $null
    $DomainDN = (get-addomain).distinguishedname
    write-log -LogText "Domain DistinguishedName: $DomainDN" -Component $component -Type Information
    Write-Verbose -Message "Domain DistinguishedName: $DomainDN"
    [string]$DomainFQDN = $null
    $DomainFQDN = (Get-ADDomain).DNSRoot
    write-log -LogText "Domain FQDN: $DomainFQDN" -Component $component -Type Information
    Write-Verbose -Message "Domain FQDN: $DomainFQDN"
    [string]$DomainController = $null
    $DomainController = (Get-ADDomain).InfrastructureMaster
    write-log -LogText "Infrastructure Master: $DomainController" -Component $component -Type Information
    Write-Verbose -Message "Infrastructure Master: $DomainController"
    [array]$AllDCs = @()
    $AllDCs = (Get-ADDomainController -Filter * -Server $DomainFQDN).hostname
    write-log -LogText "Infrastructure Master: $($AllDCs -join ',')" -Component $component -Type Information
    Write-Verbose -Message "Infrastructure Master: $($AllDCs -join ',')"
}
catch {
    write-log -LogText $_ -Component $component -Type Error
    write-log -LogText "Error in script line: $($_.InvocationInfo.ScriptLineNumber)" -Component $component -Type Error
    Write-Error $_
}

Invoke-Tiering -Tier $Tier -Path $Path -DomainDN $DomainDN
Write-Log -LogText "End Script." -Component $component -Type Information
Write-Verbose -Message "End Script."