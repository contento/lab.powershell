#requires -version 5

<#
.SYNOPSIS
Enables Policy 'Turn Off Automatic Root Certificates Update'

.DESCRIPTION
Enables Policy 'Turn Off Automatic Root Certificates Update'

.EXAMPLE
./Enable-TurnOffAutomaticRootCertificatesUpdate.ps1

.NOTES
Only For development and QA. DO NOT use in production!
#>

param (
    [Parameter(Mandatory = $false, HelpMessage = "Path to log file")]
    [string]$LogFilePath
)

#---------------------------------------------------------[Initializations]--------------------------------------------------------
Set-StrictMode -Version 2

$ErrorActionPreference = "Stop"

. "$PSScriptRoot/Write-Log.ps1"

Install-Module -Name PolicyFileEditor

Import-Module -Name PolicyFileEditor

#----------------------------------------------------------[Declarations]----------------------------------------------------------

if (!$LogFilePath) {
    $LogFilePath = "$env:SystemDrive/logs/$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)).{yyyy-MM-dd}.log"
}

#-----------------------------------------------------------[Functions]------------------------------------------------------------

function Main {
    [CmdletBinding()]
    param (
    )
    
    begin {
    }
    
    process {
        "Enabling Policy 'Turn Off Automatic Root Certificates Update' ..."

        $machineDir = "$env:windir\system32\GroupPolicy\Machine\registry.pol"
        
        $regPath = 'Software\Policies\Microsoft\SystemCertificates\AuthRoot'
        $regName = 'DisableRootAutoUpdate'
        $regData = '1'
        $regType = 'DWord'
        
        Set-PolicyFileEntry -Path $machineDir -Key $RegPath -ValueName $regName -Data $regData -Type $regType | Write-Log -UseHost -Path $LogFilePath
        
        "Done! Current value set to:" | Write-Log -UseHost -Path $LogFilePath
        Get-PolicyFileEntry -Path $machineDir -All | Write-Log -UseHost -Path $LogFilePath 
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
