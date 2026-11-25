---
title: "MCP Server for IGEL? Coming Soon"
date: 2026-11-25 06:00:00 +0100
author: robert
categories: ["IGEL", "AI"]
tags: ["igel", "igel-ums", "mcp", "ai", "claude", "imi", "open-source"]
description: "Citrix and ControlUp ship MCP servers for AI assistants. Inspired by them and by the community module PSIGEL, I started building one for the IGEL UMS. The idea, and how it will work."
image:
  path: /assets/img/posts/og-igel-ums-mcp-server.png
  alt: "MCP Server for IGEL? Coming Soon"
---

If you script against an IGEL UMS, you probably know PSIGEL. Falk Heiland's community module wraps the IGEL Management Interface (IMI), the REST API of the UMS, in PowerShell functions, and turns "log in, keep the session cookie, call the API, parse the JSON" into one line per question. This month it reached 1.0.0, now on PowerShell 7 and with certificate validation on by default. A tool like that, built and kept alive by the community, is a gift.

It also left me with a question. More and more vendors in our space now ship MCP servers, so what would one look like for IGEL?

## EUC Is Moving Towards AI

Across End-User Computing the direction is hard to miss. Vendors are bringing AI assistants into their products, and one building block keeps showing up: MCP, the Model Context Protocol. It's an open standard for connecting AI assistants to tools and data. A vendor publishes an MCP server, and an assistant like Claude, Copilot or Cursor can then ask that product questions in plain language.

Two examples from our space:

- **Citrix** offers the Citrix DaaS MCP Server, hosted in Citrix Cloud with 28 tools, all of them read-only queries and diagnostics. A local variant connects to an on-premises Delivery Controller.
- **ControlUp** offers one MCP server for all its products. It runs locally and authenticates with the customer's own credentials.

For IGEL the groundwork is already there. The IMI is a well-documented API, and PSIGEL shows how much the community can build on top of it. An MCP server felt like the natural next step, so I started building one.

## What It Will Be

An MCP server for the IGEL UMS, released as open source under the Apache 2.0 license once it's ready. You ask your UMS a question in plain language and get the answer from the real data, without clicking through the console.

Questions like these:

- Which devices are offline, and is this one reachable right now?
- Which profiles apply to this device, and in which order does the UMS rank them?
- Which firmware versions run in the fleet, and on how many devices each?
- Which devices sit below this directory?
- Document this environment for me.

An obvious objection: an assistant can already write PSIGEL scripts. Why build a server at all? Because then the assistant writes and runs new code against your UMS on every question, and whatever stops it from changing something lives only in the prompt. An MCP server offers a fixed set of tools instead. What the assistant can and can't do is decided in code, once, where you can read it.

## How It Will Probably Work

The server runs next to your AI client and talks to the IMI over HTTPS, the same API PSIGEL uses. It logs in with a dedicated UMS account, so the UMS permissions of that account decide what the assistant can see.

Read-only by design. That's the part I care about most:

- Only GET requests to documented IMI resources, plus login and logout. Every other call is refused before it leaves the machine.
- Never the shadowing data of a device. The IMI can return remote-control credentials, the server never asks for them.
- A live online check contacts the device, so the server allows it for one device at a time, never for the whole fleet.
- TLS verification stays on, with an option for an internal CA.

On top of the server comes a skill: IGEL knowledge written down for the assistant. How profile priority works, what an IGEL OS license state means, how to troubleshoot a device that doesn't register. The tools fetch the data, the skill helps the assistant read it correctly.

## Where It Stands

It runs in my lab against UMS 12.15 with IGEL OS 12 devices, in my own time and on my own hardware. IGEL kindly provided a UMS Enterprise trial license for my homelab, which unlocks the IMI. Thank you, IGEL, it made real testing possible. The core works: devices, directories, profiles and their order, firmware, live online checks.

What I don't know yet is how it behaves on a UMS with thousands of devices. My lab has three. Before a public release I want it cleaner, tested against a much larger fleet, and easy to install.

This is a community project. It is not affiliated with or endorsed by IGEL.

> If you run IGEL: what would you ask your UMS first? Your answers decide which tools come next.
{: .prompt-tip }

## Related

- [Building This Blog With Claude AI](/posts/building-this-blog-with-claude-ai/) - my first larger project with Claude as a pair programmer, the same way of working this server grows from.
- [My Second Brain: Claude, Obsidian and Git](/posts/second-brain-architecture/) - how I already use Claude in my daily EUC work, the background for wanting it to reach the UMS too.
- [USB Devices from IGEL OS into Citrix: Optimized First, Generic Last](/posts/igel-citrix-usb-redirection/) - the kind of IGEL question I would like to ask an assistant one day, with the device data at hand.

## Sources

- [PSIGEL on the PowerShell Gallery](https://www.powershellgallery.com/packages/PSIGEL/)
- [PSIGEL documentation](https://falkheiland.github.io/PSIGEL)
- [Citrix DaaS MCP Server Cloud](https://docs.citrix.com/us/en/citrix-daas/monitor/citrix-daas-mcp-cloud.html)
- [Citrix DaaS MCP Server Local](https://docs.citrix.com/us/en/citrix-aidrien/citrix-daas-mcp-local.html)
- [ControlUp MCP Server](https://support.controlup.com/mcp-server)
- [IGEL KB, IMI API v3 Device resources](https://kb.igel.com/en/igel-management-interface/current/device)
- [Model Context Protocol](https://modelcontextprotocol.io)

---

<br>

*Checked against the vendor documentation in November 2026.*

<br>

*Building something similar, or want to try it early? Reach out on [LinkedIn](https://www.linkedin.com/in/robertmagasi/).*

<br>

> *This post was written with assistance from Claude (Anthropic) as a drafting and editing tool. All technical content, solutions, and recommendations reflect my own hands-on experience and professional judgment.*
