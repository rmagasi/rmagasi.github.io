<#
.SYNOPSIS
    Test: write the 2023 Secure Boot certificates into ONE PVS target's NVRAM through Windows servicing.

.DESCRIPTION
    Run as admin on one PVS target booted from the OLD vDisk version in STANDARD mode.
    Never run it on a maintenance or private-mode device, the registry change would persist in the vDisk.

    Without -Apply the script only reports the current state (read only).
    With -Apply it sets AvailableUpdates = 0x5944, starts the Secure-Boot-Update task and
    waits until KEK and db hold the 2023 certificates, or until the timeout.

    The certificates are written to the VM's NVRAM and survive a reboot. The registry change
    and any boot manager swap stay in the write cache and are discarded at the next reboot.

.EXAMPLE
    .\Test-SecureBootNvramUpdate.ps1            # status only
    .\Test-SecureBootNvramUpdate.ps1 -Apply     # trigger the servicing and verify

.NOTES
    Background: Citrix CTX696455 (PVS targets on VMware fail with "LoadImage error: Access Denied"
    after Windows updates swap the boot manager), Microsoft KB5068202 (AvailableUpdates = 0x5944).
    Tested 2026-10-30 on Windows Server 2019 build 17763.7434 in PVS standard mode on ESXi 8.0 U3k:
    db update applied in seconds (event 1036), KEK and the remaining stages wait for a reboot (event 1800),
    so the result is PARTIAL on that build. Windows UEFI CA 2023 in db is enough to boot the 2023 boot manager.
    Afterwards: restart, run again without -Apply, the values must still be True.
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'
$sbKey    = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
$svcKey   = "$sbKey\Servicing"
$taskPath = '\Microsoft\Windows\PI\'
$taskName = 'Secure-Boot-Update'

function Test-UefiVar([string]$Name, [string]$Pattern) {
    [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI -Name $Name).Bytes) -match $Pattern
}

function Get-State {
    # The Servicing key does not exist on builds that never ran the Secure Boot servicing
    $sb  = Get-ItemProperty -Path $sbKey  -ErrorAction SilentlyContinue
    $svc = Get-ItemProperty -Path $svcKey -ErrorAction SilentlyContinue
    [pscustomobject]@{
        Time             = Get-Date -Format 'HH:mm:ss'
        KEK2023          = Test-UefiVar 'KEK' 'Microsoft Corporation KEK 2K CA 2023'
        DbWindowsCA2023  = Test-UefiVar 'db'  'Windows UEFI CA 2023'
        AvailableUpdates = if ($null -ne $sb.AvailableUpdates) { '0x{0:X}' -f $sb.AvailableUpdates } else { 'not set' }
        UEFICA2023Status = $svc.UEFICA2023Status
        UEFICA2023Error  = $svc.UEFICA2023Error
    }
}

$log = Join-Path $env:TEMP ('SecureBootNvramTest_{0}_{1:yyyyMMdd-HHmmss}.log' -f $env:COMPUTERNAME, (Get-Date))
Start-Transcript -Path $log | Out-Null
try {
    if (-not (Confirm-SecureBootUEFI)) { throw 'Secure Boot is not enabled on this VM, nothing to test.' }

    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    'Computer: {0}   OS: {1} build {2}.{3}' -f $env:COMPUTERNAME, $cv.ProductName, $cv.CurrentBuildNumber, $cv.UBR

    # A missing task is reported below, not an error at this point
    $task = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue
    'Servicing task present: {0}' -f [bool]$task

    $before = Get-State
    "`n--- Before ---"
    $before | Format-List | Out-String

    if (-not $Apply) {
        'Status only. Run again with -Apply to trigger the update.'
        return
    }
    if ($before.KEK2023 -and $before.DbWindowsCA2023) {
        'KEK and db already hold the 2023 certificates, nothing to do.'
        return
    }
    if (-not $task) {
        throw "Scheduled task $taskPath$taskName not found. This vDisk version cannot run the servicing, use the .nvram rename for this target."
    }

    $start = Get-Date
    New-ItemProperty -Path $sbKey -Name 'AvailableUpdates' -PropertyType DWord -Value 0x5944 -Force | Out-Null
    Start-ScheduledTask -TaskPath $taskPath -TaskName $taskName
    "Set AvailableUpdates = 0x5944 and started the task. Waiting up to $TimeoutSeconds seconds ..."

    do {
        Start-Sleep -Seconds 10
        $now = Get-State
        '{0}  KEK2023={1}  db2023={2}  AvailableUpdates={3}  Status={4}' -f $now.Time, $now.KEK2023, $now.DbWindowsCA2023, $now.AvailableUpdates, $now.UEFICA2023Status
    } until (($now.KEK2023 -and $now.DbWindowsCA2023) -or ((Get-Date) - $start).TotalSeconds -ge $TimeoutSeconds)

    "`n--- After ---"
    $now | Format-List | Out-String

    "--- Secure Boot servicing events since the trigger ---"
    $filter = @{
        LogName      = 'System'
        ProviderName = 'Microsoft-Windows-TPM-WMI'
        StartTime    = $start
    }
    # Get-WinEvent throws when no event matches, an empty table is the expected answer then
    Get-WinEvent -FilterHashtable $filter -ErrorAction SilentlyContinue |
        Sort-Object TimeCreated |
        Format-Table TimeCreated, Id, LevelDisplayName, Message -Wrap | Out-String

    if ($now.KEK2023 -and $now.DbWindowsCA2023) {
        'RESULT: PASS - KEK and db now hold the 2023 certificates in this VM''s NVRAM.'
        'Next: restart the target, then run the script again without -Apply. Both values must still be True.'
    }
    elseif ($now.DbWindowsCA2023) {
        'RESULT: PARTIAL - db has Windows UEFI CA 2023, KEK 2K CA 2023 is missing.'
        'The updated vDisk version should boot. The KEK is needed for future db and dbx updates.'
    }
    else {
        'RESULT: FAIL - db still lacks Windows UEFI CA 2023. Check the events above, use the .nvram rename for this target.'
    }
}
catch {
    "ERROR: $($_.Exception.Message)"
}
finally {
    Stop-Transcript | Out-Null
    "Log: $log"
    'In standard mode the log is lost at reboot, copy it off first.'
}
