#requires -version 5

<#
.SYNOPSIS
Imports a Certificate

.DESCRIPTION
Imports a certificate. Supports cer & pfx file formats

.EXAMPLE
./Import-AppCertificate.ps1 -Path ./contento.pfx -Password (ConvertTo-SecureString -String "The Plain Password" -Force)

.NOTES
#>

param (
    [Parameter(Mandatory = $false, HelpMessage = "Certificate file path")]
    [string]$Path,
    [Parameter(Mandatory = $false, HelpMessage = "Certificate Location. Default is WebHosting")]
    $CertLocation = "Cert:\LocalMachine\WebHosting",
    [Parameter(Mandatory = $false, HelpMessage = "Certificate Subject")]
    [string]$CertSubject = "CN=contento, OU=IoT, O=contento, L=Boston, S=MA, C=US",
    [Parameter(Mandatory = $false, HelpMessage = "Password in secured format")]
    [SecureString]$Password,
    [Parameter(Mandatory = $false, HelpMessage = "Force importation")]
    [Switch]$Force = $false,
    [Parameter(Mandatory = $false, HelpMessage = "Path to log file")]
    [string]$LogFilePath 
)

#---------------------------------------------------------[Initializations]--------------------------------------------------------
Set-StrictMode -Version 2

$ErrorActionPreference = "Stop"

. "$PSScriptRoot/../Functions/Util/Write-Log.ps1"
. "$PSScriptRoot/Certificates-Util.ps1"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

if (!$LogFilePath) {
    $LogFilePath = "$env:SystemDrive/logs/$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)).{yyyy-MM-dd}.log"
}

if (!$Password) {
    $Password = (ConvertTo-SecureString $plainPassword -AsPlainText -Force)
}

if (!$Path) {
    $Path = "$($PSScriptRoot)/contento.pfx"
}

#-----------------------------------------------------------[Functions]------------------------------------------------------------



#-----------------------------------------------------------[Execution]------------------------------------------------------------

function Main {
    [CmdletBinding()]
    param ()
    
    begin {
    }
   
    process {
        try {
            $cert = Import-CertificateToLocation $CertLocation $CertSubject $LogFilePath
            Test-CertificateHelper $cert $LogFilePath
        }
        finally {
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
    if (!$?) {
        $LASTEXITCODE | Write-Log -UseHost -Path $LogFilePath -Level Error
    }
    else {
        $LASTEXITCODE = 1 # Error Code 1: Incorrect function. [ERROR_INVALID_FUNCTION (0x1)]
        "Function-Generated Exit Code: $LASTEXITCODE" | Write-Log -UseHost -Path $LogFilePath -Level Error
    }
}
finally {
    $DebugPreference = $savedDebugPreference
}
