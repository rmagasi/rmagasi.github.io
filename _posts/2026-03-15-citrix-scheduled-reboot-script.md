---
title: "Automating Citrix Server Reboots — A Config-Driven PowerShell Script with User Notifications"
date: 2026-03-15 10:00:00 +0100
categories: [Citrix, PowerShell]
tags: [citrix, powershell, automation, reboot, maintenance, gpo, broker, scheduled-task]
author: robert
description: "A production-ready PowerShell script that automates Citrix server reboots with advance user notifications, maintenance mode management, and CSV-driven configuration — zero manual intervention required."
# image:
#   path: /assets/img/posts/citrix-reboot-script.png
#   alt: Citrix Scheduled Reboot Script
---

Manual Citrix server reboots are error-prone, inconsistent, and unnecessarily disruptive to end users. This post walks through a production-ready PowerShell script that automates the entire process — from enabling maintenance mode to notifying users, forcing logoff, and rebooting — all driven by a simple CSV configuration file.

## The Problem with Manual Reboots

In most Citrix environments, servers need regular reboots to stay healthy — profile cleanup, Windows Update application, memory reclamation. The typical approach is either a manual process (someone logs on, enables maintenance mode, waits, reboots) or a basic Citrix reboot schedule configured in Studio.

The problem with manual reboots is obvious — they depend on someone remembering, and they're inconsistent. The problem with Citrix's built-in reboot schedule is that it's inflexible and gives no advance warning to users who may be mid-session.

What was needed was a script that:
- Runs on a schedule with zero manual intervention
- Gives users advance notice at meaningful intervals
- Handles maintenance mode automatically
- Logs everything for auditing
- Can be configured per-server without touching the script

## The Solution: Config-Driven Reboot Automation

The script uses a CSV file to define which servers reboot on which day and at what time. One scheduled task runs daily — the script reads the CSV, checks if today matches any entries, and if so starts the reboot workflow.

### CSV Configuration

```plaintext
ServerName,DeliveryGroup,RebootDay,StartHour
CTX-WORKER-01,Production VDA,Friday,23
CTX-WORKER-02,Production VDA,Friday,23
CTX-WORKER-03,Production VDA,Saturday,23
```

Adding a new server to the reboot schedule is a one-line CSV edit. No script changes, no new scheduled tasks.

### Scheduled Task Setup

Schedule **one** task to run daily at 23:00:

```plaintext
Run as:  Citrix Scripting Service Account
Trigger: Daily at 23:00
Action:  PowerShell.exe -ExecutionPolicy Bypass -File "path\Citrix-Reboot-v2.ps1"
```

The script exits immediately if no servers are scheduled for that day and hour — so there's no overhead on non-reboot days.

## The Reboot Workflow

Once the script identifies servers scheduled for today, the workflow is:

```plaintext
T-4h   → Enable maintenance mode + first user notification
T-3h   → Notification
T-2h   → Notification
T-1h   → Notification
T-30m  → Notification
T-15m  → Final warning ("You will be logged off in 15min")
T-0    → Force logoff remaining sessions → Reboot → Disable maintenance mode
```

The notification schedule automatically adjusts based on the `RebootDelayMinutes` parameter. For testing, pass `-RebootDelayMinutes 5` to run through the entire cycle in 5 minutes.

## Key Design Decisions

### Maintenance Mode First

The script enables maintenance mode as the very first action — before any notifications go out. This ensures no new sessions land on the server during the entire reboot window. This is often missed in manual processes where someone forgets to enable maintenance mode before starting notifications.

### Notifications via Citrix Broker

User notifications use `Send-BrokerSessionMessage` — they appear as a pop-up inside the user's Citrix session, not as a Windows toast notification. This works regardless of whether the user is on a thin client, locked-down endpoint, or mobile device.

```powershell
Send-BrokerSessionMessage -InputObject $sessions `
    -MessageStyle Exclamation `
    -Title "Scheduled Maintenance" `
    -Text $message
```

### Force Logoff at T-0

Any sessions still active at reboot time are force-logged off with a 30-second grace period before the reboot command is issued:

```powershell
$sessions | Stop-BrokerSession -ErrorAction SilentlyContinue
Start-Sleep -Seconds 30
New-BrokerHostingPowerAction -MachineName $Machine.MachineName -Action Restart
```

### Maintenance Mode Disabled After Reboot

After issuing the reboot command, the script immediately disables maintenance mode. This allows the server to start accepting new sessions as soon as it comes back online — no manual step required.

### Comprehensive Logging

Every action is logged to both a timestamped transcript file and the Windows Event Log:

```plaintext
[2026-03-15 22:00:01 (UTC)] [Information] Enabling maintenance mode on: CTX-WORKER-01
[2026-03-15 22:00:02 (UTC)] [Information] [CTX-WORKER-01] Sent notification to 12 session(s)
[2026-03-15 02:00:05 (UTC)] [Information] [CTX-WORKER-01] Forcing logoff of 2 remaining session(s)
[2026-03-15 02:00:37 (UTC)] [Information] [CTX-WORKER-01] Initiated reboot
```

## Testing

The `-RebootDelayMinutes` parameter makes testing straightforward:

```powershell
# Test with 5 minute cycle
.\Citrix-Reboot-v2.ps1 -RebootDelayMinutes 5
```

This runs through the full notification and reboot cycle in 5 minutes, letting you verify the script works correctly before deploying to production.

## Requirements

- PowerShell 5.1+
- Run as Administrator
- Citrix PowerShell SDK (modules or snap-ins — the script handles both)
- Service account with Citrix delegated admin rights (Machine Administrator or higher)

## Summary

| Feature | Detail |
|---------|--------|
| Configuration | CSV file — no script changes needed |
| Scheduled Task | One daily task handles all servers |
| Notification | Up to 6 advance warnings via Citrix session pop-up |
| Maintenance Mode | Enabled at start, disabled after reboot automatically |
| Logging | Timestamped transcript + Windows Event Log |
| Testing | `-RebootDelayMinutes` parameter for quick test cycles |

## Download the Script

The full script is available to download directly:

[⬇ Download Citrix-Reboot-v2.ps1](/assets/scripts/Citrix-Reboot-v2.ps1){: .btn .btn-primary }

---

<br>

*Questions about the script or want to share how you've adapted it? Reach out on [LinkedIn](https://www.linkedin.com/in/robertmagasi/).*

<br>

> 🤖 **AI Disclosure:** The experience and technical content in this post are entirely my own, based on real-world work. Claude AI was used to help structure and articulate the writing.
