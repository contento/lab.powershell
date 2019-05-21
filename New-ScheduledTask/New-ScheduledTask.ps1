#requires -version 5
#requires -RunAsAdministrator

<#
.SYNOPSIS
  Creates or replace a Scheduled Windows Task
.DESCRIPTION
  Creates or replace a Scheduled Windows Task
.INPUTS
  None
.OUTPUTS
  log file. See $LogFilePath
.NOTES
 None
.EXAMPLE
  ./New-ScheduledTask.ps1 
.EXAMPLE
  ./New-ScheduledTask.ps1 -ConfigurationFilePath ./my-task.yaml -LogFilePath c:/logs
#>

param (
    [Parameter(Mandatory = $false, HelpMessage = "YAML configuration file")]
    [string]$ConfigurationFilePath,
    [Parameter(Mandatory = $false, HelpMessage = "Removes and creates task even if it already exists")]
    [switch]$Force,
     [Parameter(Mandatory = $false, HelpMessage = "Path to script log file")]
    [string]$LogFilePath
)

#---------------------------------------------------------[Initializations]--------------------------------------------------------

Set-StrictMode -Version 2

$ErrorActionPreference = "Stop"

. "$PSScriptRoot/Write-Log.ps1"

Import-Module ScheduledTasks
Import-Module powershell-yaml

#----------------------------------------------------------[Declarations]----------------------------------------------------------

if (!$LogFilePath) {
    $LogFilePath = "$PSScriptRoot/logs/$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)).{yyyy-MM-dd}.log"
}

$Configuration = @{}

#-----------------------------------------------------------[Functions]------------------------------------------------------------

function Get-Configuration() {
    if (!$ConfigurationFilePath) {
        $ConfigurationFilePath = "$PSScriptRoot/ScheduledTask.yaml"
    }
    $content = (Get-Content -Path $ConfigurationFilePath | Out-String)

    # macro replacements
    $content = $content -replace "{{PSScriptRoot}}", "$PSScriptRoot" 
        
    # actual conversion
    $content | ConvertFrom-Yaml 
}

function Get-TaskCredential {
    param (
    )
    $userName = $Configuration.task.user

    "Getting Credentials for user '$userName' ..." | Write-Log -UseHost -Path $LogFilePath    
    $msg = "Enter the username and password that will run the task"
    if ($userName) {
        Get-Credential -Message $msg -userName $userName
    }
    else {
        Get-Credential -Message $msg
    }
}

function Register-CustomTask {
    param (
        [PSCredential] $Credential
    )
 
    "Creating Schedule Task Action ..." | Write-Log -UseHost -Path $LogFilePath
    $taskCommand = $Configuration.action.command
    $taskCommandArguments = $Configuration.action.commandArguments
    $workingDirectory = $Configuration.action.workingDirectory
    $action = New-ScheduledTaskAction `
        -Execute $taskCommand `
        -Argument $taskCommandArguments `
        -WorkingDirectory $workingDirectory
    

    "Creating Schedule Task Trigger ..." | Write-Log -UseHost -Path $LogFilePath
    $repetitionIntervalInMinutes = Invoke-Expression $Configuration.trigger.repetitionIntervalInMinutes
    $repetitionInterval = (New-TimeSpan -Minutes $repetitionIntervalInMinutes)

    $repetitionDurationInDays = Invoke-Expression $Configuration.trigger.repetitionDurationInDays
    $now = ([DateTime]::Now)
    $timespan = $now.AddDays($repetitionDurationInDays) - $now

    $trigger = New-ScheduledTaskTrigger `
        -Once `
        -At (Get-Date).Date `
        -RepetitionInterval  $repetitionInterval `
        -RepetitionDuration $timespan
    
    "Creating Schedule Task Settings ..." | Write-Log -UseHost -Path $LogFilePath
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable `
        -DontStopOnIdleEnd
    
    "Registering Schedule Task ..." | Write-Log -UseHost -Path $LogFilePath
    $taskName = $Configuration.task.name
    $taskPathName = $Configuration.task.pathName
    $taskDescription = $Configuration.task.description
    Register-ScheduledTask `
        -TaskPath $taskPathName `
        -Action $action `
        -Trigger $trigger `
        -TaskName $taskName `
        -Description $taskDescription `
        -RunLevel Highest `
        -Settings $settings `
        -User $Credential.GetNetworkCredential().userName `
        -Password $Credential.GetNetworkCredential().Password 
}

function Main {
    [CmdletBinding()]
    param (
    )

    begin {
        $script:Configuration = Get-Configuration

        $taskName = $Configuration.task.name
        $taskPathName = $Configuration.task.pathName

        $task = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPathName -ErrorAction SilentlyContinue
        if ($task) {
            if (!$Force) {
                throw "Task '$taskPathName$taskName' already exist. Use -Force if you want to force it"
            }
            
            "Unregistering Schedule Task (-Force) ..." | Write-Log -Level Warn -UseHost -Path $LogFilePath
            Unregister-ScheduledTask -TaskPath $taskPathName -TaskName $taskName -Confirm:$false
        } 

        $Credential = Get-TaskCredential

        "Task Credentials obtained for user '$($Credential.GetNetworkCredential().userName)' ..." | Write-Log -UseHost -Path $LogFilePath
        
    }

    process {
        Register-CustomTask $Credential 
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
