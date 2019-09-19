#requires -version 5

Set-StrictMode -Version 2

$ErrorActionPreference = "Stop"


$ModulePath = $PSScriptRoot

# Only one item should be retrieved. One manifest per module
$ManifestName = (Get-ChildItem $ModulePath/*.psd1).Name 
$ModuleInfo = Test-ModuleManifest $ModulePath/$ManifestName
$ModuleName = $ModuleInfo.Name
$ModuleVersion = $ModuleInfo.Version

Remove-Module -Name $ModuleName -ErrorAction SilentlyContinue

Import-Module -Name $ModulePath/$ModuleName.psm1

$Message = "Hello world"

$LogFilePath = Get-DefaultLogFilePath 

Write-Host -ForegroundColor Cyan "Testing '$($ModuleName) $($ModuleVersion)' ..."

$Message | Write-Log -UseHost -Path $LogFilePath
$Message | Write-Log -UseHost -Path $LogFilePath -Level Warn
$Message | Write-Log -UseHost -Path $LogFilePath -Level Error
$Message | Write-Log -UseHost -Path $LogFilePath -Level Debug

Write-Warning "Also written to '$(Get-ActualLogFilePath -OriginalLogFilePath $LogFilePath)'"
