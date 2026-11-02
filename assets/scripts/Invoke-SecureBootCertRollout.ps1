<#
.SYNOPSIS
    Rollout: write the 2023 Secure Boot certificates into the NVRAM of all PVS targets in a delivery group
    through Windows servicing, and report per target which ones still need the .nvram rename.

.DESCRIPTION
    Background: Citrix CTX696455. A Windows update in maintenance mode can swap the vDisk's boot manager for
    one signed by Windows UEFI CA 2023. Targets whose VM NVRAM only holds the 2011 certificates then fail with
    "LoadImage error: Access Denied". This script prepares every target before the updated vDisk version is
    promoted.

    Run it from an admin workstation or Delivery Controller with the Citrix Broker PowerShell SDK, as an
    account that is local admin on the targets (WinRM). The targets must run the OLD vDisk version in
    STANDARD mode. Never include the maintenance VM or a device in private mode, the registry change would
    persist in the vDisk.

    Without -Apply the script only reports (read only). With -Apply it sets AvailableUpdates = 0x5944 and
    starts the Secure-Boot-Update task on every target that still lacks Windows UEFI CA 2023 in db, then
    waits for the certificate. On Server 2019 build 17763.7434 only the db stage runs before a reboot, so
    PARTIAL (db yes, KEK no) is the expected result. That is enough: the updated vDisk version boots and
    adds the KEK and the remaining 2023 certificates by itself at first boot.

    Result per target:
      AlreadyOK     db already holds Windows UEFI CA 2023, nothing to do
      NeedsUpdate   report mode only, db lacks the certificate
      PASS          KEK and db now hold the 2023 certificates
      PARTIAL       db now holds Windows UEFI CA 2023, KEK follows at first boot of the updated version
      FAIL          db still lacks the certificate after the timeout, use the .nvram rename (option A)
      NoTask        Secure-Boot-Update task missing on this build, use option A
      SecureBootOff Secure Boot disabled on this VM, not affected
      PoweredOff    not running, power it on and rerun, or use option A
      Unreachable   WinRM failed, check access, or use option A

.PARAMETER DeliveryGroup
    Delivery group whose machines are processed.

.PARAMETER AdminAddress
    Delivery Controller to query. Default: the local machine.

.PARAMETER ComputerName
    Process these machines instead of a delivery group (FQDN or NetBIOS names).

.PARAMETER ExcludeComputerName
    Machines to skip, for example the maintenance VM.

.PARAMETER Apply
    Trigger the update. Without it the script only reports.

.PARAMETER TimeoutSeconds
    How long each target waits for the db certificate after the trigger. Default 90.

.PARAMETER ThrottleLimit
    Parallel remote sessions. Default 16.

.PARAMETER ReportPath
    CSV report. Default: .\SecureBootCertRollout_<yyyyMMdd-HHmmss>.csv

.EXAMPLE
    .\Invoke-SecureBootCertRollout.ps1 -DeliveryGroup 'Desktop' -AdminAddress ddc01 -ExcludeComputerName pvs-maint01
    Report only.

.EXAMPLE
    .\Invoke-SecureBootCertRollout.ps1 -DeliveryGroup 'Desktop' -AdminAddress ddc01 -ExcludeComputerName pvs-maint01 -Apply
    Trigger the update on every target that needs it and write the CSV report.

.NOTES
    Tested approach: Test-SecureBootNvramUpdate.ps1 on one target, 2026-10-30 to 2026-11-02, Windows Server 2019
    17763.7434 to 17763.9376, PVS 2402 LTSR, ESXi 8.0 U3k. The rollout script itself has not run in production yet.
    References: Citrix CTX696455, Microsoft KB5068202.
#>
[CmdletBinding(DefaultParameterSetName = 'DeliveryGroup')]
param(
    [Parameter(Mandatory, ParameterSetName = 'DeliveryGroup')]
    [string]$DeliveryGroup,

    [Parameter(ParameterSetName = 'DeliveryGroup')]
    [string]$AdminAddress = 'localhost',

    [Parameter(Mandatory, ParameterSetName = 'ComputerName')]
    [string[]]$ComputerName,

    [string[]]$ExcludeComputerName = @(),

    [switch]$Apply,

    [int]$TimeoutSeconds = 90,

    [int]$ThrottleLimit = 16,

    [string]$ReportPath = (Join-Path (Get-Location) ('SecureBootCertRollout_{0:yyyyMMdd-HHmmss}.csv' -f (Get-Date)))
)

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "*** Starting Secure Boot certificate rollout (Apply: $Apply) - $((Get-Date).ToUniversalTime())"

# ---------------------------------------------------------------------------
# 1. Collect the targets
# ---------------------------------------------------------------------------
$targets = @()
$results = New-Object System.Collections.Generic.List[object]

if ($PSCmdlet.ParameterSetName -eq 'DeliveryGroup') {
    try {
        if (-not (Get-Command Get-BrokerMachine -ErrorAction SilentlyContinue)) {
            Add-PSSnapin Citrix.Broker.Admin.V2 -ErrorAction Stop
        }
        $machines = Get-BrokerMachine -DesktopGroupName $DeliveryGroup -AdminAddress $AdminAddress -MaxRecordCount 10000 -ErrorAction Stop
    }
    catch {
        throw "Could not read delivery group '$DeliveryGroup' from $AdminAddress : $($_.Exception.Message)"
    }

    foreach ($m in $machines) {
        $name = $m.DNSName
        if (-not $name) { $name = ($m.MachineName -split '\\')[-1] }
        $short = ($name -split '\.')[0]
        if ($ExcludeComputerName -contains $name -or $ExcludeComputerName -contains $short) { continue }

        if ($m.PowerState -ne 'On') {
            $results.Add([pscustomobject]@{
                Computer         = $name
                Result           = 'PoweredOff'
                DbWindowsCA2023  = $null
                KEK2023          = $null
                AvailableUpdates = $null
                UEFICA2023Status = $null
                Build            = $null
                Detail           = "PowerState $($m.PowerState), maintenance mode $($m.InMaintenanceMode)"
            })
            continue
        }
        $targets += $name
    }
}
else {
    foreach ($name in $ComputerName) {
        $short = ($name -split '\.')[0]
        if ($ExcludeComputerName -contains $name -or $ExcludeComputerName -contains $short) { continue }
        $targets += $name
    }
}

Write-Host "Targets to contact: $($targets.Count), already marked PoweredOff: $($results.Count)"

# ---------------------------------------------------------------------------
# 2. Remote work on each target
# ---------------------------------------------------------------------------
$remote = {
    param([bool]$DoApply, [int]$Timeout)

    $sbKey    = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
    $taskPath = '\Microsoft\Windows\PI\'
    $taskName = 'Secure-Boot-Update'

    function Get-State {
        # The Servicing key does not exist on builds that never ran the Secure Boot servicing
        $sb  = Get-ItemProperty -Path $sbKey -ErrorAction SilentlyContinue
        $svc = Get-ItemProperty -Path "$sbKey\Servicing" -ErrorAction SilentlyContinue
        $kek = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI -Name KEK).Bytes)
        $db  = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI -Name db).Bytes)
        $au  = 'not set'
        if ($null -ne $sb.AvailableUpdates) { $au = '0x{0:X}' -f $sb.AvailableUpdates }
        [pscustomobject]@{
            Db               = ($db -match 'Windows UEFI CA 2023')
            Kek              = ($kek -match 'Microsoft Corporation KEK 2K CA 2023')
            AvailableUpdates = $au
            Status           = $svc.UEFICA2023Status
        }
    }

    $cv    = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = '{0}.{1}' -f $cv.CurrentBuildNumber, $cv.UBR
    $out   = [ordered]@{
        Computer         = $env:COMPUTERNAME
        Result           = $null
        DbWindowsCA2023  = $null
        KEK2023          = $null
        AvailableUpdates = $null
        UEFICA2023Status = $null
        Build            = $build
        Detail           = $null
    }

    try {
        if (-not (Confirm-SecureBootUEFI)) {
            $out.Result = 'SecureBootOff'
            $out.Detail = 'Secure Boot disabled, not affected'
            return [pscustomobject]$out
        }

        $state = Get-State
        $out.DbWindowsCA2023  = $state.Db
        $out.KEK2023          = $state.Kek
        $out.AvailableUpdates = $state.AvailableUpdates
        $out.UEFICA2023Status = $state.Status

        if ($state.Db) {
            $out.Result = 'AlreadyOK'
            return [pscustomobject]$out
        }
        if (-not $DoApply) {
            $out.Result = 'NeedsUpdate'
            return [pscustomobject]$out
        }

        # A missing task is reported, not thrown
        $task = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue
        if (-not $task) {
            $out.Result = 'NoTask'
            $out.Detail = 'Secure-Boot-Update task not found, use the .nvram rename'
            return [pscustomobject]$out
        }

        $start = Get-Date
        New-ItemProperty -Path $sbKey -Name 'AvailableUpdates' -PropertyType DWord -Value 0x5944 -Force -ErrorAction Stop | Out-Null
        Start-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction Stop

        do {
            Start-Sleep -Seconds 5
            $state = Get-State
        } until ($state.Db -or ((Get-Date) - $start).TotalSeconds -ge $Timeout)

        $out.DbWindowsCA2023  = $state.Db
        $out.KEK2023          = $state.Kek
        $out.AvailableUpdates = $state.AvailableUpdates
        $out.UEFICA2023Status = $state.Status

        $filter = @{
            LogName      = 'System'
            ProviderName = 'Microsoft-Windows-TPM-WMI'
            StartTime    = $start
        }
        # Get-WinEvent throws when no event matches, an empty list is a valid answer here
        $ids = (Get-WinEvent -FilterHashtable $filter -ErrorAction SilentlyContinue | Sort-Object TimeCreated | ForEach-Object { $_.Id }) -join ','
        $out.Detail = "Events: $ids"

        if ($state.Db -and $state.Kek) { $out.Result = 'PASS' }
        elseif ($state.Db)             { $out.Result = 'PARTIAL' }
        else                           { $out.Result = 'FAIL' }
    }
    catch {
        $out.Result = 'FAIL'
        $out.Detail = "Error: $($_.Exception.Message)"
    }
    [pscustomobject]$out
}

if ($targets.Count -gt 0) {
    $remoteErrors = $null
    try {
        $returned = Invoke-Command -ComputerName $targets -ScriptBlock $remote -ArgumentList ([bool]$Apply), $TimeoutSeconds `
            -ThrottleLimit $ThrottleLimit -ErrorAction SilentlyContinue -ErrorVariable remoteErrors
    }
    catch {
        throw "Invoke-Command failed: $($_.Exception.Message)"
    }

    $answered = @()
    foreach ($r in $returned) {
        $answered += $r.PSComputerName
        $results.Add([pscustomobject]@{
            Computer         = $r.PSComputerName
            Result           = $r.Result
            DbWindowsCA2023  = $r.DbWindowsCA2023
            KEK2023          = $r.KEK2023
            AvailableUpdates = $r.AvailableUpdates
            UEFICA2023Status = $r.UEFICA2023Status
            Build            = $r.Build
            Detail           = $r.Detail
        })
    }

    # Everything that did not answer is unreachable, with the WinRM error where there is one
    foreach ($t in $targets) {
        if ($answered -contains $t) { continue }
        $err = $remoteErrors | Where-Object { $_.TargetObject -eq $t -or "$($_.OriginInfo.PSComputerName)" -eq $t } | Select-Object -First 1
        $msg = 'No answer'
        if ($err) { $msg = $err.Exception.Message }
        $results.Add([pscustomobject]@{
            Computer         = $t
            Result           = 'Unreachable'
            DbWindowsCA2023  = $null
            KEK2023          = $null
            AvailableUpdates = $null
            UEFICA2023Status = $null
            Build            = $null
            Detail           = $msg
        })
    }
}

# ---------------------------------------------------------------------------
# 3. Report
# ---------------------------------------------------------------------------
$results | Sort-Object Result, Computer | Format-Table Computer, Result, DbWindowsCA2023, KEK2023, AvailableUpdates, Build -AutoSize

Write-Host '--- Summary ---'
$results | Group-Object Result | Sort-Object Name | Format-Table Name, Count -AutoSize

$needA = @($results | Where-Object { $_.Result -in 'FAIL', 'NoTask', 'Unreachable', 'PoweredOff' })
if ($needA.Count -gt 0) {
    Write-Host "Option A (.nvram rename) or a rerun needed for: $(($needA | ForEach-Object { $_.Computer }) -join ', ')"
}
$open = @($results | Where-Object { $_.Result -eq 'NeedsUpdate' })
if ($open.Count -gt 0) {
    Write-Host "$($open.Count) targets need the update. Rerun with -Apply."
}

try {
    $results | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
    Write-Host "Report: $ReportPath"
}
catch {
    Write-Warning "Could not write the report: $($_.Exception.Message)"
}

$stopwatch.Stop()
Write-Host "*** Ending Secure Boot certificate rollout - Time taken: $($stopwatch.Elapsed)"
