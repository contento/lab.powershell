#requires -version 5

<#
.SYNOPSIS
Force IIS site to use SSL

.DESCRIPTION
Force IIS site to use SSL

.EXAMPLE
.\Force-Ssl.ps1 -UseIisSslFlag
use IIS Flag

.EXAMPLE
.\Force-Ssl.ps1 -UseRewriteModule -UseIisSslFlag:$false
Use Rewrite Module but do not set IIS required flag

.EXAMPLE
.\Force-Ssl.ps1  -UseIisSslFlag -UseRewriteModule
Use both Rewrite Module and IIS required flag
.NOTES
See:
  http://dloder.blogspot.com/2015/05/deploy-iis-url-rewrite-rules-using.html
#>

param (
    [Parameter(Mandatory = $false, HelpMessage = "Use IIS SSL Flag (default)")] 
    [switch]$UseIisSslFlag,
    [Parameter(Mandatory = $false, HelpMessage = "Use Rewrite Module")] 
    [switch]$UseRewriteModule,
    [Parameter(Mandatory = $false, HelpMessage = "Path to log file")]
    [string]$LogFilePath
)

#---------------------------------------------------------[Initializations]--------------------------------------------------------
Set-StrictMode -Version 2

$ErrorActionPreference = "Stop"

. "$PSScriptRoot/Write-Log.ps1"

Import-Module IISAdministration

#----------------------------------------------------------[Declarations]----------------------------------------------------------

if (!$LogFilePath) {
    $LogFilePath = "$env:SystemDrive/logs/$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)).{yyyy-MM-dd}.log"
}

#-----------------------------------------------------------[Functions]------------------------------------------------------------

function Set-IisSslFlag {
    param (
    )
    "Setting IIS SSL Flags ..." | Write-Log -UseHost -Path $LogFilePath
    $ConfigSection = Get-IISConfigSection -SectionPath "system.webServer/security/access" -Location "Default Web Site"
    
    Set-IISConfigAttributeValue -AttributeName sslFlags -AttributeValue Ssl -ConfigElement $ConfigSection
    
    Get-IISConfigAttributeValue -ConfigElement $ConfigSection -AttributeName sslFlags | Write-Log -UseHost -Path $LogFilePath  
}

function Set-RewriteSslRules {
    param (
    )
    "Adding SSL URL rewriting rules ..." | Write-Log -UseHost -Path $LogFilePath

    $ruleName = "HTTPS Redirect"
    $sitePath = 'IIS:\Sites\Default Web Site'
    $rewritePathRules = "system.webserver/rewrite/rules"
    $filterRoot = "$rewritePathRules/rule[@name='$ruleName']"
    
    Clear-WebConfiguration -pspath $sitePath -filter $filterRoot

    $rule = @{
        name           = $ruleName
        patternSyntax  = 'Wildcard'
        stopProcessing = 'True'
        match          = @{
            url        = '*'
            ignoreCase = 'True'
            negate     = 'False'
        }
        conditions     = @{
            logicalGrouping = 'MatchAny'
        }
        action         = @{
            type              = 'Redirect'
            url               = 'https://{HTTP_HOST}{REQUEST_URI}'
            appendQueryString = 'true'
            redirectType      = 'Found'
        }
    }
    Add-WebConfigurationProperty -PSPath $sitePath -Filter $rewritePathRules -Name "." -Value $rule | Write-Log -UseHost -Path $LogFilePath

    $match = @{
        input      = '{HTTPS}'
        matchType  = 'Pattern'
        pattern    = 'off'
        ignoreCase = 'True'
        negate     = 'False'
    }
    Add-WebConfigurationProperty -PSPath $sitePath -Filter "$filterRoot/conditions" -Name "." -Value $match | Write-Log -UseHost -Path $LogFilePath   
}

function Main {
    [CmdletBinding()]
    param ( 
    )
    
    begin {
    }
    
    process {
        if ($UseIisSslFlag) {
            Set-IisSslFlag 
        }
        if ($UseRewriteModule) {
            Set-RewriteSslRules
        }
    }
    
    end {
    }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

try {
    $savedDebugPreference = $DebugPreference
    #! Enable next line if you want to see the Debug Output
    # $DebugPreference = "Continue"

    $duration = Measure-Command { Main }
    "Done! $duration" | Write-Log -UseHost -Path $LogFilePath
}
catch {
    $_.Exception | Write-Log -UseHost -Path $LogFilePath -Level Error
    if ($LASTEXITCODE -eq 0) {
        # Force Error Code 1: Incorrect function. [ERROR_INVALID_FUNCTION (0x1)]
        $LASTEXITCODE = 1 
        "Function-Generated Exit Code: $LASTEXITCODE" | Write-Log -UseHost -Path $LogFilePath -Level Error
    }
}
finally {
    $DebugPreference = $savedDebugPreference
}
