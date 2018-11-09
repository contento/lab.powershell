"Importing Module ..."
Import-Module -Name $PSScriptRoot/Logging.psm1 -Verbose 

"Demostrating Write-Log ..."

$LogFilePath = "$env:SystemDrive/logs/$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)).{yyyy-MM-dd}.log"

"Information (Only Host)" | Write-Log -Level "Info" -UseHost 

"Writing messages to both Host & '$LogFilePath' ..."
@("Error", "Warn", "Info", "Debug") | ForEach-Object {
    "'$_' Message" | Write-Log -Level $_ -UseHost -Path $LogFilePath
}
