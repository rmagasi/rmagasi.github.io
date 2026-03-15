---
title: "Citrix Session Shadowing Broken After January 2026 Patches — Here's the Fix"
date: 2026-03-15 09:00:00 +0100
categories: [Citrix, Troubleshooting]
tags: [citrix, director, shadowing, msra, gpo, firewall, remote-assistance, windows-update]
author: robert_magasi
---

Citrix Director's built-in shadowing stopped working for many environments after the January 2026 Microsoft patches. If your support team is suddenly unable to shadow user sessions, you're not alone — and there is a working workaround using Windows Remote Assistance (msra.exe).

<!--more-->

## What Broke

The January 2026 Microsoft cumulative updates appear to have broken the native Citrix Director shadowing functionality on Windows Server-based VDAs. Sessions can no longer be shadowed directly from the Director console.

This is an escalation-level issue for support teams — shadowing is often the first tool engineers reach for when helping users with application issues, and losing it silently causes real operational pain.

## The Workaround: MSRA-Based Shadowing via Director Server

The solution uses Windows Remote Assistance (`msra.exe`) with the `/offerra` switch — the "offer remote assistance" mode — which allows a support engineer to initiate a session to a specific worker without the end user needing to request help first.

The flow looks like this:

1. Support Engineer connects to their **Citrix Desktop**
2. From there, RDP to the **Citrix Director server**
3. On the Director server, launch: `C:\Windows\System32\msra.exe /offerra`
4. Enter the **hostname of the Citrix Worker** where the user session is running
5. Connect — the user will see a prompt to accept the shadowing request

> 💡 **Tip:** Prepare a shortcut on the Director server's Public Desktop pointing to `C:\Windows\System32\msra.exe /offerra` so support engineers don't need to remember the path.

## Prerequisites

### 1. Find the Worker Hostname

Before shadowing, the support engineer needs to know which Citrix Worker the user is connected to. This is visible in **Citrix Director → Sessions → select the session → Machine details**.

### 2. GPO — Enable Remote Assistance on Workers

A GPO must be in place linked to the **Citrix Workers OU** to enable Windows Remote Assistance. Configure the following settings under:

`Computer Configuration → Administrative Templates → System → Remote Assistance`

| Setting | Value |
|---------|-------|
| Configure Offer Remote Assistance | Enabled |
| Permit remote control of this computer | Enabled |
| Helpers | Add the Director server computer account or support group |

### 3. Firewall Rules — Critical Step

This is where most implementations get stuck. TCP/135 (RPC Endpoint Mapper) is usually already open, but Windows Remote Assistance also requires **dynamic high ports** to be open.

You need the following host-based firewall rules on the **Citrix Workers**:

| Direction | Protocol | Port | Source | Destination |
|-----------|----------|------|--------|-------------|
| Inbound | TCP | 135 | Director Servers | Citrix Workers Subnet |
| Inbound | TCP | 49152–65535 | Director Servers | Citrix Workers Subnet |

> ⚠️ **Important:** Without the dynamic high port range open, the RPC connection will fail silently after the initial handshake on port 135. This is the most common reason the workaround appears not to work.

These rules should be deployed via GPO to the Workers OU:

`Computer Configuration → Windows Settings → Security Settings → Windows Firewall with Advanced Security → Inbound Rules`

Create two inbound rules:
- **Rule 1:** TCP 135, source = Director server IPs
- **Rule 2:** TCP 49152–65535, source = Director server IPs

## Step-by-Step for Support Engineers

Once the GPO and firewall rules are in place, the support workflow is:

```
1. Connect to your Citrix Desktop
2. RDP to Director Server (e.g. director01.domain.local)
3. Open Citrix Director → find the user session → note the Worker hostname
4. Launch: C:\Windows\System32\msra.exe /offerra
   (or use the shortcut on the Public Desktop)
5. Enter the Worker hostname (e.g. CTX-WORKER-01)
6. Click OK — the user receives a Remote Assistance request
7. User accepts → shadowing begins
```

## Why This Works

The `/offerra` switch puts MSRA into "unsolicited offer" mode — the helper initiates the connection rather than waiting for the user to send an invitation. This bypasses the broken Director shadowing path entirely and uses the underlying Windows Remote Assistance infrastructure directly.

The jump via the Director server is important — it ensures the connection originates from a trusted, centrally managed server with the correct firewall rules in place, rather than from individual support engineer desktops which may have inconsistent network access to the Workers subnet.

## Summary

| Component | Action Required |
|-----------|----------------|
| Director Server | Add `msra.exe /offerra` shortcut to Public Desktop |
| Workers GPO | Enable and configure Offer Remote Assistance |
| Workers Firewall | Open TCP 135 + TCP 49152–65535 from Director servers |
| Support Process | RDP to Director first, then launch msra.exe |

This workaround is fully supportable, requires no third-party tools, and can be deployed entirely via GPO. Until Microsoft or Citrix releases a patch addressing the January 2026 regression, this is a reliable alternative for session shadowing.

---

*Have you found a different fix for the Director shadowing regression? Reach out on [LinkedIn](https://www.linkedin.com/in/robertmagasi/).*

> 🤖 **AI Disclosure:** The experience and technical content in this post are entirely my own, based on real-world work. Claude AI was used to help structure and articulate the writing.
