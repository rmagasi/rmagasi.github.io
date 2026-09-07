---
title: "HDX Connection Time, the Logon Phase You Should Be Checking"
date: 2026-09-06 09:00:00 +0200
author: robert
categories: ["Citrix", "Troubleshooting"]
tags: ["citrix-daas", "rendezvous", "adaptive-transport", "edt", "hdx", "gateway-service", "session-logon-duration", "director"]
description: "HDX connection time should be a couple of seconds. When it is 15 to 20, the transport negotiation is failing and every user pays for it on every launch. How to read it, why it happens, and what to do."
image:
  path: /assets/img/posts/og-citrix-hdx-connection-time-rendezvous.png
  alt: "HDX Connection Time, the Logon Phase You Should Be Checking"
---

Everyone reads the Session Logon Duration total. Almost nobody reads the phase breakdown underneath it, and HDX connection is the phase that gets skipped most often. It should take a second or two. When it takes 18, something in the transport negotiation is failing, and every user is paying for it on every single launch.

Sometimes that shows up as slow logons that people just live with. Sometimes it pushes the total past a launch timeout and you get failures that look random. Either way the number is telling you something specific, and it is worth learning to read.

## What the Phase Actually Measures

HDX connection is the part of the launch where the client and the VDA agree on a transport and establish the ICA connection. It happens before authentication, before GPOs, before logon scripts, before anything you would normally tune. If it is slow, everything behind it starts late.

Here is what a bad one looks like.

![Session Logon Duration breakdown in Citrix Director showing a total of 1 minute 54 seconds with the HDX connection phase at 18.36 seconds](/assets/img/posts/hdx-rendezvous-logon-prod.png){: w="900" }
_18.36 seconds in HDX connection, on a session that took 1 minute 54 seconds in total. The rest of the breakdown is unremarkable. The whole chain just starts 18 seconds late._

Nothing else in that breakdown is dramatic. That is the point. When one phase is an order of magnitude out and the others are ordinary, you have a specific fault, not a general performance problem.

## Why It Gets Long

The usual cause is a transport that is configured but not actually available. Two Citrix policy settings do this, and they are easy to enable without the network to back them.

![Citrix policy settings showing HDX adaptive transport at the default Preferred and Rendezvous Protocol set to Allowed](/assets/img/posts/hdx-rendezvous-policy-before.png){: w="620" }
_Rendezvous Protocol explicitly Allowed, HDX adaptive transport left at its Preferred default. Both are reasonable settings, and both need the firewall to cooperate._

**Rendezvous Protocol** lets the VDA bypass the Cloud Connectors and talk directly to the Gateway Service. It needs outbound access from the VDA to `*.*.nssvc.net`, TCP 443 for control traffic and TCP plus UDP 443 for HDX sessions, with Session Reliability enabled on the VDA.

**HDX adaptive transport** at Preferred means the client tries EDT over UDP and falls back to TCP if that fails. Through the Gateway Service, EDT depends on Rendezvous and needs UDP 443 outbound from the VDA.

When those preconditions are missing, Citrix documents the consequence directly:

> If EDT negotiation fails for any reason, the session falls back to TCP with Rendezvous. And if that fails, then the session falls back to proxying through the Cloud Connectors.
>
> Citrix, [HDX adaptive transport with EDT support for Citrix Gateway service](https://docs.citrix.com/en-us/citrix-gateway-service/hdx-edt-support-for-gateway-service.html)

That is three attempts in a fixed order, and each one has to fail before the next begins.

![Flowchart of HDX connection establishment in Citrix DaaS through the Gateway Service, showing EDT Rendezvous, then TCP Rendezvous, then TCP through the Cloud Connector, each with a connection success decision leading to session established or the next attempt](/assets/img/posts/hdx-rendezvous-connection-flow.png){: w="850" }
_The documented order, with the transport stack each attempt produces. These are the strings `ctxsession.exe` reports, so you can match a live session to the attempt it landed on._

The session does connect in the end, which is exactly why nobody flags it. It just pays the full price of two failed attempts first.

Monitor's session launch diagnostics names it plainly when you look.

![Citrix Monitor session launch diagnostics showing a VDA error, outbound Rendezvous connection attempt from VDA to Citrix Gateway rendezvous point over TCP failed, code RENDEZVOUS_CONNECT_FAILED_TCP](/assets/img/posts/hdx-rendezvous-launch-diagnostic.png){: w="700" }
_RENDEZVOUS\_CONNECT\_FAILED\_TCP. Worth reading precisely, this does not say UDP is blocked. It says the VDA could not reach the rendezvous point over TCP either, so both legs of Rendezvous were unavailable._

## How to Check It

Five things, none of which need a support case.

1. **Read the phase breakdown, not the total.** In Director, open a session and look at Session Logon Duration. Double-digit HDX connection means stop looking at GPOs and profiles. You are in the wrong half of the launch.
2. **Check the Protocol field.** Same session details view. Connection type HDX with protocol UDP means EDT is working. TCP means it is not, whatever the policy says it should be.
3. **Run `ctxsession.exe -v` inside the session.** A working EDT session reports `UDP > CGP > ICA`, or `UDP > DTLS > CGP > ICA` with end to end encryption. Anything starting with TCP tells you adaptive transport is not delivering.
4. **Use session launch diagnostics on a failed launch.** Search the transaction ID in Monitor and it names the component and the error code. For a launch that died on time rather than on error, look for `CGS-ICASN_ERR_00006`, a Gateway Service connection request to the Connector that timed out, or `XDPXY_ERR_00002`, the proxy timing out waiting on the VDA.
5. **Check the firewall before you check the policy.** If `*.*.nssvc.net` is not reachable on the required ports, the policy setting is not the problem, it is just the thing that makes the missing rule expensive.

> This is worth doing even when nothing is failing. A 15 second HDX connection phase on a working environment is 15 seconds every user loses on every launch. It will never generate a ticket, and it is one of the cheapest things you will ever fix.
{: .prompt-tip }

## What to Do About It

**If the network can support it, fix the network.** Rendezvous and EDT are a genuine improvement when their preconditions are met. Open the outbound rules, verify with `ctxsession.exe`, and keep both settings enabled. This is the better long term answer.

**If it cannot, turn both off explicitly.** Do not leave them enabled and failing.

![Citrix policy settings showing HDX adaptive transport set to Off and Rendezvous Protocol set to Prohibited](/assets/img/posts/hdx-rendezvous-policy-after.png){: w="620" }
_Adaptive transport Off, Rendezvous Protocol Prohibited. The session ends up on TCP through the Cloud Connector either way, this just stops it trying two paths that cannot work first._

The result is immediate, because you are not changing the transport that ends up being used. You are only removing the failed attempts in front of it.

![Session Logon Duration breakdown showing a total of 52 seconds with the HDX connection phase at 6.15 seconds against a 7 day average of 16.61 seconds](/assets/img/posts/hdx-rendezvous-logon-int.png){: w="900" }
_The same environment with both settings disabled. HDX connection down to 6.15 seconds against a 7 day average of 16.61, and the total logon down with it._

That also makes the change low risk to argue for. Sessions are already connecting over TCP through the Cloud Connectors today. Disabling both settings does not move anyone onto a new path, it stops them queueing behind two that were never going to work.

> Enabling Rendezvous or adaptive transport without the matching firewall rules is worse than leaving them off. They do not fail loudly, they fail slowly, and the cost is paid on every session launch.
{: .prompt-warning }

## One Thing Not to Do

Do not raise the launch timeout. It is the obvious lever when launches die at a consistent duration, and for published applications on a multi-session VDA that lever is `ApplicationLaunchWaitTimeoutMS` under `HKLM\SYSTEM\CurrentControlSet\Control\Citrix\wfshell\TWI`. Published desktops on a single-session VDA have their own, `AutoLogonTimeout` under `HKLM\SOFTWARE\Citrix\PortICA`, which defaults to 180 seconds on VDA 7.6 and later.

Both are worth knowing about, and neither is worth increasing. A launch that needs 110 seconds still needs 110 seconds after you give it 300, and the user still waits. Raising it buys silence, not speed, and it removes the one signal that was telling you something is wrong.

## Sources

- Citrix, [Rendezvous V2](https://docs.citrix.com/en-us/citrix-daas/hdx-transport/rendezvous-protocol/rendezvous-v2.html)
- Citrix, [Adaptive transport](https://docs.citrix.com/en-us/citrix-virtual-apps-desktops/hdx-transport/adaptive-transport.html)
- Citrix, [Adaptive transport troubleshooting](https://docs.citrix.com/en-us/citrix-daas/hdx-transport/adaptive-transport/troubleshooting3.html)
- Citrix, [HDX adaptive transport with EDT support for Citrix Gateway service](https://docs.citrix.com/en-us/citrix-gateway-service/hdx-edt-support-for-gateway-service.html)
- Citrix, [Session launch diagnostics](https://docs.citrix.com/en-us/citrix-daas/monitor/session_launch_diagnostics.html)
- Citrix, [Published applications or desktops do not launch or disappear during launch (CTX200393)](https://support.citrix.com/external/article/CTX200393/published-applications-or-desktops-do-no.html)

---

<br>

*Checked your HDX connection time and found something interesting? Reach out on [LinkedIn](https://www.linkedin.com/in/robertmagasi/).*

<br>

> *This post was written with assistance from Claude (Anthropic) as a drafting and editing tool. All technical content, solutions, and recommendations reflect my own hands-on experience and professional judgment.*
