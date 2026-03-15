<#
.SYNOPSIS
    Citrix Server Scheduled Reboot Script (Config-Driven)

.DESCRIPTION
    Reboots servers based on a CSV configuration file with a fixed notification schedule:
    - T-4h: Enable maintenance mode, first notification
    - T-3h, T-2h, T-1h, T-30min: Hourly notifications
    - T-15min: Final warning
    - T-0: Force logoff and reboot, disable maintenance mode

    The script reads from a CSV file to determine which servers to reboot on which day.
    Schedule ONE task to run daily at 23:00 - the script handles the rest.

.PARAMETER ConfigPath
    Path to the CSV configuration file. Default: RebootSchedule.csv in script directory.

.PARAMETER LogPath
    Path for log file output. Default: Script\Logs directory.

.PARAMETER RebootDelayMinutes
    Minutes from script start until reboot. Default: 240 (4 hours).
    Notification schedule automatically adjusts based on this value.
    For testing, use smaller values like 5 or 10.

.EXAMPLE
    .\Citrix-Reboot-v2.ps1

.EXAMPLE
    .\Citrix-Reboot-v2.ps1 -ConfigPath "D:\Scripts\Citrix-RebootSchedule.csv" -LogPath "D:\Logs"

.EXAMPLE
    # Quick test with 5 minute delay
    .\Citrix-Reboot-v2.ps1 -RebootDelayMinutes 5

.NOTES
    Version:        2.0
    Last Modified:  2025

    CSV Format:
    ServerName,DeliveryGroup,RebootDay,StartHour
    Server01,Production VDA,Friday,23

    Scheduled Task Setup:
    - Run as: Citrix Scripting Service Account
    - Trigger: Daily at 23:00
    - Action: PowerShell.exe -ExecutionPolicy Bypass -File "path\Citrix-Reboot-v2.ps1"
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Path to CSV configuration file")]
    [string]$ConfigPath,

    [Parameter(HelpMessage = "Path for log files")]
    [string]$LogPath,

    [Parameter(HelpMessage = "Minutes until reboot (default: 240 = 4 hours)")]
    [int]$RebootDelayMinutes = 240
)

# Handle PSScriptRoot being empty (e.g., when run via Task Scheduler)
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }

# Set defaults if not provided
if (-not $ConfigPath) { $ConfigPath = Join-Path -Path $scriptDir -ChildPath "Citrix-RebootSchedule.csv" }
if (-not $LogPath) { $LogPath = $scriptDir }

#region Configuration
$script:Config = @{
    EventLogSource = "Citrix Reboot Script"
    EventLogName   = "Application"
}

# Build notification schedule based on RebootDelayMinutes
$script:NotificationSchedule = @()

if ($RebootDelayMinutes -ge 240) {
    $script:NotificationSchedule += @{ MinutesBefore = 240; Message = "Server will be rebooted in 4h, please re-login to ensure session continuity" }
}
if ($RebootDelayMinutes -ge 180) {
    $script:NotificationSchedule += @{ MinutesBefore = 180; Message = "Server will be rebooted in 3h, please re-login to ensure session continuity" }
}
if ($RebootDelayMinutes -ge 120) {
    $script:NotificationSchedule += @{ MinutesBefore = 120; Message = "Server will be rebooted in 2h, please re-login to ensure session continuity" }
}
if ($RebootDelayMinutes -ge 60) {
    $script:NotificationSchedule += @{ MinutesBefore = 60; Message = "Server will be rebooted in 1h, please re-login to ensure session continuity" }
}
if ($RebootDelayMinutes -ge 30) {
    $script:NotificationSchedule += @{ MinutesBefore = 30; Message = "Server will be rebooted in 30min, please re-login to ensure session continuity" }
}
if ($RebootDelayMinutes -ge 15) {
    $script:NotificationSchedule += @{ MinutesBefore = 15; Message = "You will be logged off in 15min" }
}
if ($RebootDelayMinutes -ge 5 -and $RebootDelayMinutes -lt 15) {
    $script:NotificationSchedule += @{ MinutesBefore = 5; Message = "You will be logged off in 5min" }
}
if ($RebootDelayMinutes -ge 1 -and $RebootDelayMinutes -lt 5) {
    $script:NotificationSchedule += @{ MinutesBefore = 1; Message = "You will be logged off in 1min" }
}
#endregion

#region Logging Functions
function Initialize-Logging {
    [CmdletBinding()]
    param()

    if (-not (Test-Path -Path $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $dayOfWeek = (Get-Date).ToString("dddd")
    $script:TranscriptPath = Join-Path -Path $LogPath -ChildPath "\Logs\Citrix-Reboot_${dayOfWeek}_${timestamp}.log"
    Start-Transcript -Path $script:TranscriptPath -Append

    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($script:Config.EventLogSource)) {
            New-EventLog -LogName $script:Config.EventLogName -Source $script:Config.EventLogSource -ErrorAction Stop
        }
    }
    catch {
        Write-Warning "Could not create Event Log source: $($_.Exception.Message)"
    }
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Level = 'Information',

        [int]$EventId = 1000
    )

    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
    $logMessage = "[$timestamp (UTC)] [$Level] $Message"

    switch ($Level) {
        'Error'       { Write-Host $logMessage -ForegroundColor Red }
        'Warning'     { Write-Host $logMessage -ForegroundColor Yellow }
        'Information' { Write-Host $logMessage -ForegroundColor Green }
    }

    try {
        $entryType = switch ($Level) {
            'Error'   { [System.Diagnostics.EventLogEntryType]::Error }
            'Warning' { [System.Diagnostics.EventLogEntryType]::Warning }
            default   { [System.Diagnostics.EventLogEntryType]::Information }
        }

        Write-EventLog -LogName $script:Config.EventLogName `
                       -Source $script:Config.EventLogSource `
                       -EventId $EventId `
                       -EntryType $entryType `
                       -Message $Message `
                       -ErrorAction SilentlyContinue
    }
    catch { }
}
#endregion

#region Citrix Functions
function Initialize-CitrixEnvironment {
    [CmdletBinding()]
    param()

    try {
        if (Get-Module -ListAvailable -Name Citrix.DelegatedAdmin.Commands -ErrorAction SilentlyContinue) {
            Import-Module Citrix.* -ErrorAction Stop
            Write-Log -Message "Initializing Citrix PowerShell environment. Citrix PowerShell modules loaded" -EventId 1001
        }
        else {
            Add-PSSnapin Citrix* -ErrorAction Stop
            Write-Log -Message "Initializing Citrix PowerShell environment. Citrix PowerShell snap-ins loaded" -EventId 1002
        }
    }
    catch {
        Write-Log -Message "Failed to load Citrix PowerShell components: $($_.Exception.Message)" -Level Error -EventId 2001
        throw
    }
}

function Get-TargetMachine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName,

        [Parameter(Mandatory = $true)]
        [string]$DeliveryGroup
    )

    try {
        $machine = Get-BrokerMachine -DesktopGroupName $DeliveryGroup `
                                      -HostedMachineName $ServerName `
                                      -ErrorAction Stop

        if ($null -eq $machine) {
            throw "Machine '$ServerName' not found in Delivery Group '$DeliveryGroup'"
        }

        return $machine
    }
    catch {
        Write-Log -Message "Failed to retrieve machine $ServerName : $($_.Exception.Message)" -Level Error -EventId 2010
        throw
    }
}

function Set-MaintenanceMode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Machine,

        [Parameter(Mandatory = $true)]
        [bool]$Enable
    )

    $action = if ($Enable) { "Enabling" } else { "Disabling" }
    $machineName = $Machine.HostedMachineName

    try {
        Set-BrokerMachine -InputObject $Machine -InMaintenanceMode $Enable -ErrorAction Stop
        Write-Log -Message "$action maintenance mode on: $machineName" -EventId 1020
    }
    catch {
        Write-Log -Message "Failed to set maintenance mode on ${machineName}: $($_.Exception.Message)" -Level Error -EventId 2020
        throw
    }
}

function Send-UserNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Machine,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $machineName = $Machine.HostedMachineName

    try {
        $sessions = Get-BrokerSession -MachineName $Machine.MachineName -ErrorAction Stop

        if ($sessions.Count -gt 0) {
            Send-BrokerSessionMessage -InputObject $sessions `
                                      -MessageStyle Exclamation `
                                      -Title "Scheduled Maintenance" `
                                      -Text $Message `
                                      -ErrorAction Stop

            Write-Log -Message "[$machineName] Sent notification to $($sessions.Count) session(s)" -EventId 1030
        }
        else {
            Write-Log -Message "[$machineName] No active sessions - skipping notification" -EventId 1031
        }
    }
    catch {
        Write-Log -Message "[$machineName] Failed to send notification: $($_.Exception.Message)" -Level Warning -EventId 3030
    }
}

function Invoke-ServerReboot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Machine
    )

    $machineName = $Machine.HostedMachineName

    try {
        # Force logoff remaining sessions
        $sessions = Get-BrokerSession -MachineName $Machine.MachineName -ErrorAction SilentlyContinue
        if ($sessions.Count -gt 0) {
            Write-Log -Message "[$machineName] Forcing logoff of $($sessions.Count) remaining session(s)" -Level Warning -EventId 1040
            $sessions | Stop-BrokerSession -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 30
        }

        # Initiate restart
        New-BrokerHostingPowerAction -MachineName $Machine.MachineName -Action Restart -ErrorAction Stop | Out-Null
        Write-Log -Message "[$machineName] Initiated reboot" -EventId 1041

        # Disable maintenance mode
        Set-BrokerMachine -InputObject $Machine -InMaintenanceMode $false -ErrorAction Stop
        Write-Log -Message "[$machineName] Disabled maintenance mode" -EventId 1042

        return $true
    }
    catch {
        Write-Log -Message "[$machineName] Failed to reboot: $($_.Exception.Message)" -Level Error -EventId 2040
        return $false
    }
}

function Wait-UntilTime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [DateTime]$TargetTime
    )

    $waitSeconds = ($TargetTime - (Get-Date)).TotalSeconds

    if ($waitSeconds -gt 0) {
        Write-Log -Message "Waiting until $($TargetTime.ToString('yyyy-MM-dd HH:mm:ss')) ($([math]::Round($waitSeconds / 60, 1)) minutes)" -EventId 1050
        Start-Sleep -Seconds $waitSeconds
    }
}

function Get-TodaysServers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    if (-not (Test-Path -Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    $today = (Get-Date).ToString("dddd")
    $currentHour = (Get-Date).Hour

    $allServers = Import-Csv -Path $ConfigPath
    $todaysServers = @($allServers | Where-Object {
        $_.RebootDay -eq $today -and [int]$_.StartHour -eq $currentHour
    })

    return $todaysServers
}
#endregion

#region Main Execution
try {
    $todaysServers = Get-TodaysServers -ConfigPath $ConfigPath

    if ($todaysServers.Count -eq 0) {
        Initialize-Logging
        $today = (Get-Date).ToString("dddd")
        $currentHour = (Get-Date).Hour
        Write-Log -Message "No servers scheduled for reboot on $today at $($currentHour):00. Exiting." -EventId 1000
        exit 0
    }

    $scriptStartTime = Get-Date
    $rebootTime = $scriptStartTime.AddMinutes($RebootDelayMinutes)

    Initialize-Logging

    $serverNames = ($todaysServers | ForEach-Object { $_.ServerName }) -join ", "
    $serverCount = ($todaysServers | Measure-Object).Count
    $startTime = $scriptStartTime.ToString('yyyy-MM-dd HH:mm:ss')
    $rebootTimeStr = $rebootTime.ToString('yyyy-MM-dd HH:mm:ss')

    $startMessage = @"
Citrix Server Reboot Script Started
============================================================
Servers scheduled: $serverNames
Server count: $serverCount
Script Start: $startTime
Scheduled Reboot: $rebootTimeStr
============================================================
"@
    Write-Log -Message $startMessage -EventId 1000

    Initialize-CitrixEnvironment

    $activeServers = @()
    foreach ($server in $todaysServers) {
        try {
            Write-Log -Message "[$($server.ServerName)] Retrieving machine from Delivery Group: $($server.DeliveryGroup)" -EventId 1010
            $machine = Get-TargetMachine -ServerName $server.ServerName -DeliveryGroup $server.DeliveryGroup
            Write-Log -Message "[$($server.ServerName)] Found machine: $($machine.MachineName), PowerState: $($machine.PowerState), Sessions: $($machine.SessionCount)" -EventId 1011

            Set-MaintenanceMode -Machine $machine -Enable $true

            $activeServers += @{
                ServerName    = $server.ServerName
                DeliveryGroup = $server.DeliveryGroup
            }
        }
        catch {
            Write-Log -Message "[$($server.ServerName)] Failed to initialize - skipping: $($_.Exception.Message)" -Level Error -EventId 2010
        }
    }

    if ($activeServers.Count -eq 0) {
        Write-Log -Message "No servers could be initialized. Exiting." -Level Error -EventId 2000
        exit 1
    }

    foreach ($notification in $script:NotificationSchedule) {
        $notificationTime = $rebootTime.AddMinutes(-$notification.MinutesBefore)
        Wait-UntilTime -TargetTime $notificationTime
        Write-Log -Message "Sending notifications: T-$($notification.MinutesBefore)min" -EventId 1060

        foreach ($server in $activeServers) {
            try {
                $machine = Get-TargetMachine -ServerName $server.ServerName -DeliveryGroup $server.DeliveryGroup
                Send-UserNotification -Machine $machine -Message $notification.Message
            }
            catch {
                Write-Log -Message "[$($server.ServerName)] Error during notification: $($_.Exception.Message)" -Level Warning -EventId 3060
            }
        }
    }

    Wait-UntilTime -TargetTime $rebootTime
    Write-Log -Message "Starting server reboots" -EventId 1070

    $successCount = 0
    $failedCount = 0

    foreach ($server in $activeServers) {
        try {
            $machine = Get-TargetMachine -ServerName $server.ServerName -DeliveryGroup $server.DeliveryGroup
            $rebootSuccess = Invoke-ServerReboot -Machine $machine
            if ($rebootSuccess) { $successCount++ } else { $failedCount++ }
        }
        catch {
            Write-Log -Message "[$($server.ServerName)] Reboot failed: $($_.Exception.Message)" -Level Error -EventId 2070
            $failedCount++
        }
    }

    $resultLevel = if ($failedCount -eq 0) { 'Information' } else { 'Warning' }
    $resultText = if ($failedCount -eq 0) { 'SCRIPT COMPLETED SUCCESSFULLY' } else { 'SCRIPT COMPLETED WITH ERRORS' }

    $endMessage = @"
Citrix Server Reboot Script $resultText
============================================================
Servers rebooted: $successCount
Servers failed: $failedCount
============================================================
"@
    Write-Log -Message $endMessage -Level $resultLevel -EventId 1099
}
catch {
    Write-Log -Message "SCRIPT FAILED: $($_.Exception.Message)" -Level Error -EventId 2099
    Write-Log -Message "Stack Trace: $($_.ScriptStackTrace)" -Level Error -EventId 2099
    exit 1
}
finally {
    try { Stop-Transcript } catch { }
}
#endregion
