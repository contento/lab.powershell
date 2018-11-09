#requires -version 5

<#
.SYNOPSIS
Creates a Self-Signed Certificate

.DESCRIPTION
Creates a Self-Signed Certificate and then exports them to both .cer and .pfx.
Notice the .pfx contains the Private Key and it has to be secure with password.

.EXAMPLE
./Create-SelfSignedCertificate.ps1 -Password (ConvertTo-SecureString -String "The Plain Password" -Force –AsPlainText) -LogFilePath c:/logs/vmseep.logs

.NOTES
Fine tune according with your needs
#>

param (
    [Parameter(Mandatory = $false, HelpMessage = "Certificate Folder Path")]
    [string]$FolderPath, 
    [Parameter(Mandatory = $false, HelpMessage = "Certificate Name")]
    [string]$Name = "contento",
    [Parameter(Mandatory = $false, HelpMessage = "Certificate Subject")]
    [string]$CertSubject = "CN=contento, OU=IoT, O=contento, L=Boston, S=MA, C=US",
    [Parameter(Mandatory = $false, HelpMessage = "Password in secured format")]
    [SecureString]$Password,
    [Parameter(Mandatory = $false, HelpMessage = "Path to log file")]
    [string]$LogFilePath 
)

#---------------------------------------------------------[Initializations]--------------------------------------------------------

Set-StrictMode -Version 2

$ErrorActionPreference = "Stop"

. "$PSScriptRoot/../Functions/Util/Write-Log.ps1"
. "$PSScriptRoot/Certificates-Util.ps1"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

if (!$FolderPath) {
    $baseFilePath = "$($PSScriptRoot)/$($Name)"
}
else {
    $baseFilePath = "$($FolderPath)/$($Name)"
}

if (!$LogFilePath) {
    $LogFilePath = "$env:SystemDrive/logs/$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)).{yyyy-MM-dd}.log"
}

$javaKeyAlias = "java-key-alias"

if (!$Password) {
    $Password = (ConvertTo-SecureString $plainPassword -AsPlainText -Force)
}

#-----------------------------------------------------------[Functions]------------------------------------------------------------

function New-TemporarySelfSignedCertificate {
    param (
    )
    "Create Self-Signed Certificate ..." | Write-Log -UseHost -Path $LogFilePath

    $psVersion = $PSVersionTable.PSVersion 
    if ($psVersion.Major -eq 5 -and $psVersion.Minor -eq 1 -and $psVersion.Revision -lt 2312) {
        Write-Error "PowerShell $psVersion doesn't support 'Subject Alternative Name'" 
    }

        New-SelfSignedCertificate `
        -DnsName $(Get-WildcardDnsName), $(Get-ComputerDnsName), "localhost" `
        -Subject $CertSubject `
            -CertStoreLocation $personalCertLocation `
            -KeyExportPolicy Exportable `
            -KeySpec KeyExchange
    }

function Export-ToCer {
    param (
        $cert
    )
    # You may want to use -Protect + Windows AD
    "Export to .cer (only Public Key) ..." | Write-Log -UseHost -Path $LogFilePath
    Export-Certificate -Cert $cert -Type CERT -FilePath "$baseFilePath.cer" | 
        Write-Log -UseHost -Path $LogFilePath
}

function Export-ToPfx {
    param (
        $cert
    )
    "Export to .pfx (Private Key + Password) ..." | Write-Log -UseHost -Path $LogFilePath
    Export-PfxCertificate -Cert $cert -Password $script:Password -FilePath "$baseFilePath.pfx" | 
        Write-Log -UseHost -Path $LogFilePath    
}

function Export-ToJks {
    param (
        $cert
    )
    "Export to Java .jks ..." | Write-Log -UseHost -Path $LogFilePath

    # get the cert GUID which is the Friendly Name (alias name)
    $l = (./keytool.exe -v -list -keystore "$baseFilePath.pfx" -storetype pkcs12 -storepass $plainPassword | Out-String)

    $l -match "Alias name: ([{\w{2}-]*\w{8}-\w{4}-\w{4}-\w{4}-\w{12})" 
    if (!$Matches) {
        Write-Error "I could not determine the Alias Name for the certificate in '$baseFilePath.pfx'"
    }

    $aliasName = $Matches[1]

    if (Test-Path -Path "$baseFilePath.jks") {
        Remove-Item -Path "$baseFilePath.jks"
    }

    ./keytool.exe `
        -importkeystore `
        -srckeystore "$baseFilePath.pfx" -srcstoretype pkcs12 -srcstorepass "$plainPassword" -srcalias $aliasName `
        -destkeystore "$baseFilePath.jks" -deststoretype JKS -deststorepass "$plainPassword" -destalias $javaKeyAlias 
}

function Main {
    [CmdletBinding()]
    param ()
    
    begin {
        $cert = $null
    }
   
    process {
        try {
            $cert = New-TemporarySelfSignedCertificate 
            if (!$cert -or $cert -is [array] -or $cert.GetType().Name -ne "X509Certificate2") {
                $errorMessage = "Could not create a temporary certificate. Got ($cert)"
                $cert = $null
                throw $errorMessage 
            }

            Test-CertificateHelper $cert $LogFilePath

            Export-ToCer $cert

            Export-ToPfx $cert

            Export-ToJks $cert
        }
        finally {
            if ($cert) {            
                $certPath = $cert.PSPath
                "Removing Self-Signed Certificate '$certPath' from store ..." | Write-Log -UseHost -Path $LogFilePath 
                Remove-Item -Path $certPath -DeleteKey -ErrorAction SilentlyContinue | Write-Log -UseHost -Path $LogFilePath
                }
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
