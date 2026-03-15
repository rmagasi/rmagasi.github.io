---
title: "How a StoreFront Keyword Trick Saved a Customer Six Figures in Licensing Costs"
date: 2026-03-14 09:00:00 +0100
categories: [Citrix, Troubleshooting]
tags: [citrix, storefront, tags, fslogix, gpo, licensing, session-affinity]
author: robert_magasi
image:
  path: /assets/img/posts/session-affinity-diagram.png
  alt: Non-Personal Account Session Affinity Solution Architecture
---

Some of the best solutions in IT aren't complex — they're elegant. This is a story about a critical production escalation that multiple vendors and colleagues said couldn't be solved without expensive custom development or a major architecture overhaul. It could. Using nothing but native Citrix features.

<!--more-->

## The Situation

A customer was running a Citrix Server OS (RDSH) environment with FSLogix Profile Containers. Their setup involved **non-personalised accounts** — shared credentials with different account names (e.g. Service-Account-A, Service-Account-B, Service-Account-C) — that needed access to specific backend resources.

The problem: whenever two or more of these accounts landed on the **same Citrix worker server simultaneously**, the backend application produced errors or failed outright. The application simply couldn't handle multiple of these accounts sharing the same server at the same time.

This had escalated to **senior management level**. Operations were significantly disrupted. And the obvious fix — converting to personalised user accounts — would have required purchasing hundreds of additional backend application licences, representing a **significant six-figure investment** the customer could not justify.

Several colleagues and vendors had already told the customer this was unsolvable without either:

1. Expensive custom development
2. Major architectural changes
3. Moving to personalised accounts (with all the licensing cost that entails)

## My Task

I needed to solve this critical production problem urgently — while **preserving the non-personalised account model**. The constraint was clear: these accounts must never land on the same worker server at the same time. Ever.

The pressure was high. The customer was escalating at executive level, facing both operational disruption and potentially massive licensing costs.

## The Solution: Four Layers, All Native Citrix

After analysing the root cause, I realised the resource conflicts were caused purely by simultaneous sessions landing on the same worker. The fix was to enforce **strict session affinity** — ensuring each account was permanently bound to its own dedicated worker server.

![Session Affinity Solution Architecture](/assets/img/posts/session-affinity-diagram.png)
_Full architecture diagram showing the four-layer session affinity solution_

Here's how I built it using only native Citrix features:

### Layer 1 — Endpoint Routing via GPO

I configured Citrix Workspace App via Group Policy to point each endpoint group to a **dedicated StoreFront store URL**.

- Endpoint Group A → `https://storefront.company.com/Citrix/StoreA`
- Endpoint Group B → `https://storefront.company.com/Citrix/StoreB`

GPO filtering based on computer OU or security group applied the correct Workspace App settings automatically. Endpoints never needed manual configuration.

### Layer 2 — StoreFront Keyword Filtering

In Citrix Studio, I added **Keywords** to the published applications/desktops. In the StoreFront stores, I configured each store to only display resources matching a specific keyword.

- Store A only shows resources tagged with keyword `WorkerGroup-A`
- Store B only shows resources tagged with keyword `WorkerGroup-B`

This means users connecting through Store A can only ever see and launch resources destined for Worker Group A. Cross-contamination at the enumeration level is impossible.

### Layer 3 — Citrix Tags on Individual Workers

Here's the part that kept the solution simple: rather than creating multiple Delivery Groups (which would have added unnecessary complexity), I **tagged each VDA individually** in Citrix Studio and used a **single Delivery Group**.

- Worker-01 → Tag: `WorkerGroup-A`
- Worker-02 → Tag: `WorkerGroup-A`
- Worker-03 → Tag: `WorkerGroup-B`
- Worker-04 → Tag: `WorkerGroup-B`

The combination of the keyword on the published resource and the tag on the VDA ensures the Delivery Controller routes sessions to the correct worker every time. One Delivery Group. No custom brokering logic. No code.

### Layer 4 — FSLogix Profile Separation via GPO

To prevent profile conflicts, I organised the VDA servers into separate OUs in Active Directory and applied **worker-specific GPOs** setting unique FSLogix `VHDLocations` paths per worker:

- Worker-01 → `\\srv\profiles\worker01`
- Worker-02 → `\\srv\profiles\worker02`
- Worker-03 → `\\srv\profiles\worker03`
- Worker-04 → `\\srv\profiles\worker04`

Each worker maintains completely isolated profile storage, regardless of which account connects.

## The Result

The solution was deployed to production and immediately resolved the application conflicts. The non-personalised account model was preserved entirely. The customer avoided the six-figure licensing cost they had been facing.

The whole thing was built using **native Citrix features** — no custom development, no major architecture changes, no new licences.

One final touch: I documented the solution thoroughly for the operations team, including a tip that's easy to miss — **enable the Tags column in Citrix Studio's Machine Catalogs view** so the ops team can see which workers carry which tags when troubleshooting. Without that, the routing logic is invisible to anyone maintaining the environment.

## Key Takeaways

**Sometimes the elegant solution is the simple one.** Multiple vendors said this required custom development. It didn't. It required understanding how StoreFront keywords and Citrix tags interact — and using them together intentionally.

**One Delivery Group is enough.** There's a temptation to create separate Delivery Groups for each worker group. Unnecessary. Tag the VDAs individually, use a single Delivery Group, and let the keyword + tag combination handle the routing.

**Document for the ops team, not just for yourself.** A solution is only good if the team maintaining it can understand and troubleshoot it. The Tags column tip in Studio is a small thing — but it's the difference between an ops engineer diagnosing a routing issue in two minutes versus two hours.

---



*Have you used StoreFront keywords in a similar way? I'd be interested to hear other creative uses of this feature — reach out on [LinkedIn](https://www.linkedin.com/in/robertmagasi/).*



&nbsp;

> 🤖 **AI Disclosure:** The experience and technical content in this post are entirely my own, based on real-world work. Claude AI was used to help structure and articulate the writing.
