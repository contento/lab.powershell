#requires -version 5

<#
.SYNOPSIS
Assign App Certificate to Site

.DESCRIPTION
Creates a Self-Signed Certificate and then exports them to both .cer and .pfx.
Notice the .pfx contains the Private Key and it has to be secure with password.

.EXAMPLE
./Create-SelfSignedCertificate.ps1 -Password (ConvertTo-SecureString -String "The Plain Password" -Force –AsPlainText)

.NOTES
Fine tune according with your needs
#>

param (
    [Parameter(Mandatory = $false, HelpMessage = "Web Site Name")]
    [string]$WebSiteName = "Default Web Site",
    [Parameter(Mandatory = $false, HelpMessage = "Certificate Location. Default is WebHosting")]
    $CertLocation = "Cert:\LocalMachine\WebHosting",
    [Parameter(Mandatory = $false, HelpMessage = "Certificate Subject")]
    [string]$CertSubject = "CN=contento, OU=IoT, O=contento, L=Boston, S=MA, C=US",
    [Parameter(Mandatory = $false, HelpMessage = "Remove SSL Bindings if they exist")]
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

$sslIPAddressess = "0.0.0.0"
$sslPort = 443
$sslBindingIP = "*"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

function New-WebSslBinding {
    param (
    )
    "-- New SSL Binding ... " | Write-Log -UseHost -Path $LogFilePath

    $httpsBinding = Get-WebBinding $WebSiteName | Where-Object { $_.protocol -eq "https" }
    if ($httpsBinding) {
        if ($Force) {
            "Binding already existed. Removing (-Force was used)" | Write-Log -Level Warn -UseHost -Path $LogFilePath
            Remove-WebBinding -Name $WebSiteName -IP $sslBindingIP -Port $sslPort -Protocol https
        }
        else {
            "Binding already existed. Skipping. Use -Force if you need to recreate it" | Write-Log -Level Warn -UseHost -Path $LogFilePath
            return;
        }
    }

    New-WebBinding -Name $WebSiteName -IP $sslBindingIP -Port $sslPort -Protocol https
}

function Set-Certificate {
    param (
    )
    "-- Apply Certificates to Binding ... " | Write-Log -UseHost -Path $LogFilePath

    Import-Module WebAdministration

    Push-Location IIS:\SslBindings
    try {
        if (Test-Path $sslIPAddressess!$sslPort) {
            if ($Force) {
                "Certificate already applied. Removing (-Force was used)" | Write-Log -Level Warn -UseHost -Path $LogFilePath
                Remove-Item -Path $sslIPAddressess!$sslPort -Force
            }
            else {
                "Certificate already applied. Skipping. Use -Force if you need to recreate it" | Write-Log -Level Warn -UseHost -Path $LogFilePath
                return
            }
        }

        $cert = Get-CertificateFrom $CertLocation $CertSubject 
        if (!$cert) {
            Write-Error "A certificate was not found for '$CertSubject'"          
        }

        $cert | New-Item $sslIPAddressess!$sslPort  
    }
    finally {
        Pop-Location       
    }
}

function Main {
    [CmdletBinding()]
    param ()
    
    begin {
    }
   
    process {
        New-WebSslBinding 
        Set-Certificate 
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
