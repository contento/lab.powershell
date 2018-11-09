#----------------------------------------------------------[Declarations]----------------------------------------------------------

$personalCertLocation = "Cert:\LocalMachine\My"
$trustedCertLocation = "Cert:\LocalMachine\AuthRoot"
$webHostingCertLocation = "Cert:\LocalMachine\WebHosting"
$plainPassword = "The!Super!Password!"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

function Get-CertificateFrom {
    param (
        [Parameter(Mandatory = $true)]
        [string] $certLocation,
        [Parameter(Mandatory = $true)]
        $certSubject
    )
    Get-ChildItem $certLocation | Where-Object { $_.Subject -contains $certSubject }   
}

function Import-CertificateToLocation {
    param (
        [Parameter(Mandatory = $true)]
        [string] $certLocation,
        [Parameter(Mandatory = $true)]
        $certSubject,
        [Parameter(Mandatory = $true, HelpMessage = "Path to log file")]
        [string]$LogFilePath 
    
    )
    "-- Importing Certificate with subject '$certSubject' ... " | Write-Log -UseHost -Path $LogFilePath

    $cert = Get-CertificateFrom $certLocation $certSubject
    if ($cert) {
        "Certificate already exists" | Write-Log -Level Warn -UseHost -Path $LogFilePath
        if (!$Force) {
            "Remove it or use -Force to re-import it" | Write-Log -Level Warn -UseHost -Path $LogFilePath
            return $cert
        }

        "Removing certificate" | Write-Log -Level Warn -UseHost -Path $LogFilePath
        Remove-Item -Path $cert.PSPath -DeleteKey | Write-Log -UseHost -Path $LogFilePath
    }

    $ext = [IO.Path]::GetExtension($Path)
    if ($ext -eq ".cer") {
        Import-Certificate -FilePath $Path -CertStoreLocation $certLocation | Write-Log -Path $LogFilePath
    }
    elseif ($ext -eq ".pfx") {
        Import-PfxCertificate -FilePath $Path -CertStoreLocation $certLocation  -Password $Password | Write-Log -Path $LogFilePath
    }
    else {
        Write-Error "Extension '$ext' not supported"
    }
    
    Get-CertificateFrom $certLocation $certSubject
}

function Get-CertificateFromPersonal {
    param (
        [Parameter(Mandatory = $true)]
        $certSubject
    )
    Get-CertificateFrom $personalCertLocation $certSubject   
}

function Get-CerticateFromTrusted {
    param (
        [Parameter(Mandatory = $true)]
        $certSubject
    )
    Get-CertificateFrom $trustedCertLocation $certSubject    
}

function Get-CerticateFromWebHosting {
    param (
        [Parameter(Mandatory = $true)]
        $certSubject
    )
    Get-CertificateFrom $webHostingCertLocation $certSubject    
}

function Get-WildcardDnsName {
    param (
    )
    "*.$(Get-ConnectionSpecificSuffix)"
}

function Get-ComputerDnsName {
    param (
    )
    "$env:COMPUTERNAME.$(Get-ConnectionSpecificSuffix)"
}

function Get-ConnectionSpecificSuffix {
    param (
    )
    $savedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"

    try {
        $dnsClientEntries = Get-DnsClient | Where-Object { -not ([string]::IsNullOrEmpty($_.ConnectionSpecificSuffix)) } 

        Get-NetAdapter | Where-Object { $_.Status -eq "Up"} | ForEach-Object { 
            $interfaceAlias = $_.Name
            try {
                $dnsEntry = $dnsClientEntries | Where-Object { $_.InterfaceAlias -eq $interfaceAlias }
                if ($dnsEntry -and $dnsEntry.ConnectionSpecificSuffix) {
                    # return the first Suffix, the others are going to be empty
                    return $dnsEntry.ConnectionSpecificSuffix
                }
            }
            catch {
                Write-Debug "It is not possible to determine the DNS Information for '$interfaceAlias'" 
            }
        }
    }
    finally {
        $ErrorActionPreference = $savedErrorActionPreference  
    }     
}


function Test-CertificateHelper {
    param (
        $cert,
        [Parameter(Mandatory = $true, HelpMessage = "Path to log file")]
        [string]$LogFilePath 
        )
    "Testing Certificate ..." | Write-Log -UseHost -Path $LogFilePath
    if (!$cert) {
        throw "Could not test certificate: Certificate is empty" 
    }

    $result = Test-Certificate $cert -Policy SSL -AllowUntrustedRoot -ErrorAction Continue
    $result | Write-Log -UseHost -Path $LogFilePath      
}
