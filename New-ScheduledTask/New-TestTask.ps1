. "$PSScriptRoot/Write-Log.ps1"

$LogFilePath = "$PSScriptRoot/logs/$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)).{yyyy-MM-dd}.log"

"Hello world!" | Write-Log -Path $LogFilePath
