---
title: "How a StoreFront Keyword Trick Saved a Customer Six Figures in Licensing Costs"
date: 2026-03-14 09:00:00 +0100
categories: ["Citrix", "Troubleshooting"]
tags: ["citrix", "storefront", "fslogix", "gpo", "licensing", "session-affinity"]
author: robert
description: "How native Citrix StoreFront keywords and VDA tags solved a production escalation - and avoided a six-figure licensing bill. No custom code required."
image:
  path: /assets/img/posts/og-storefront-licensing.png
  alt: "How a StoreFront Keyword Trick Saved a Customer Six Figures in Licensing Costs"
---

I was already on the way home when my manager called. The customer was escalating - executive level, production disrupted, and the options on the table were custom development or a six-figure licensing spend. I put everything else aside the next day and started from scratch. What I found was a solution built entirely from native Citrix features that nobody had thought to combine.

## The Situation

A customer was running a Citrix Server OS (RDSH) environment with FSLogix Profile Containers. Their setup involved **non-personalised accounts** - shared credentials with different account names (e.g. Service-Account-A, Service-Account-B, Service-Account-C) - that needed access to specific backend resources.

The problem: whenever two or more of these accounts landed on the **same Citrix worker server simultaneously**, the backend application produced errors or failed outright. The application simply couldn't handle multiple of these accounts sharing the same server at the same time.

This had escalated to **senior management level**. Operations were significantly disrupted. And the obvious fix - converting to personalised user accounts - would have required purchasing hundreds of additional backend application licences, representing a **significant six-figure investment** the customer could not justify.

Several colleagues and vendors had already told the customer this was unsolvable without either:

1. Expensive custom development
2. Major architectural changes
3. Moving to personalised accounts (with all the licensing cost that entails)

## My Task

I needed to solve this critical production problem urgently - while **preserving the non-personalised account model**. The constraint was clear: these accounts must never land on the same worker server at the same time. Ever.

The pressure was high. The customer was escalating at executive level, facing both operational disruption and potentially massive licensing costs.

## The Solution: Four Layers, All Native Citrix

After analysing the root cause, I realised the resource conflicts were caused purely by simultaneous sessions landing on the same worker. The fix was to enforce **strict session affinity** - ensuring each account was permanently bound to its own dedicated worker server.

<div class="sa-figure">
<style>
.sa-figure {
  --bg: #fafafa; --card: #ffffff; --ink: #1d1d1f; --ink-2: #34343a;
  --ink-3: #6b6b72; --ink-4: #a6a6ad; --hair: #e9e9ec; --hair-2: #f2f2f4;
  --a: #2a408e; --a-soft: #eaeefb; --a-ink: #1f2f69;
  --b: #b54708; --b-soft: #fdf0e3; --b-ink: #7a3207;
  --ok: #2e7d32; --code-bg: #f6f6f8;
  --radius: 6px; --radius-sm: 4px;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", "Lato", Arial, sans-serif;
  font-size: 14px; line-height: 1.5;
  color: var(--ink);
  max-width: 860px;
  margin: 16px auto 24px;
  -webkit-font-smoothing: antialiased;
}
html[data-mode="dark"] .sa-figure {
  --bg: #1b1b1f; --card: #232328; --ink: #f5f5f7; --ink-2: #d9d9de;
  --ink-3: #9a9aa4; --ink-4: #6b6b72; --hair: #33333a; --hair-2: #2a2a2f;
  --a: #7aa2f7; --a-soft: #1f2b4a; --a-ink: #c8d4f0;
  --b: #e8a87c; --b-soft: #3a2418; --b-ink: #f3c8a8;
  --ok: #81c784; --code-bg: #2a2a30;
}
.sa-figure *, .sa-figure *::before, .sa-figure *::after { box-sizing: border-box; margin: 0; box-shadow: none; text-shadow: none; }
.sa-figure div { background: transparent; border-radius: 0; }
.sa-figure .mono { font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace; font-size: 0.9em; }
.sa-figure .diagram { background: var(--card); border: 1px solid var(--hair); border-radius: var(--radius); overflow: hidden; }
.sa-figure .layers { display: grid; grid-template-columns: 48px repeat(4, 1fr); background: var(--hair-2); border-bottom: 1px solid var(--hair); }
.sa-figure .layers .cell { padding: 10px 12px 12px; border-right: 1px solid var(--hair); position: relative; background: transparent; }
.sa-figure .layers .cell:last-child { border-right: none; }
.sa-figure .layers .tag { font-size: 10px; font-weight: 600; letter-spacing: 0.1em; text-transform: uppercase; color: var(--ink-4); margin-bottom: 3px; }
.sa-figure .layers .name { font-size: 13px; font-weight: 700; color: var(--ink); line-height: 1.25; }
.sa-figure .layers .mech { font-size: 11px; color: var(--ink-3); margin-top: 2px; }
.sa-figure .rail { display: grid; grid-template-columns: 48px repeat(4, 1fr); position: relative; }
.sa-figure .rail + .rail { border-top: 1px solid var(--hair); }
.sa-figure .rail-chip { display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 14px; letter-spacing: 0.02em; border-right: 1px solid var(--hair); }
.sa-figure .rail-a .rail-chip { background: var(--a-soft); color: var(--a-ink); }
.sa-figure .rail-b .rail-chip { background: var(--b-soft); color: var(--b-ink); }
.sa-figure .rail-chip span { display: inline-flex; align-items: center; justify-content: center; width: 26px; height: 26px; border-radius: 50%; background: var(--card); font-size: 12px; }
.sa-figure .rail-a .rail-chip span { color: var(--a); box-shadow: inset 0 0 0 1.5px var(--a); }
.sa-figure .rail-b .rail-chip span { color: var(--b); box-shadow: inset 0 0 0 1.5px var(--b); }
.sa-figure .node { padding: 12px 14px 14px; border-right: 1px solid var(--hair); position: relative; min-height: 140px; background: var(--card); }
.sa-figure .node:last-child { border-right: none; }
.sa-figure .node .cap { display: inline-flex; align-items: center; gap: 6px; font-size: 10.5px; font-weight: 600; letter-spacing: 0.08em; text-transform: uppercase; color: var(--ink-3); margin-bottom: 6px; }
.sa-figure .node .cap::before { content: ""; display: inline-block; width: 6px; height: 6px; border-radius: 1px; background: var(--ink-4); }
.sa-figure .rail-a .node .cap { color: var(--a); }
.sa-figure .rail-a .node .cap::before { background: var(--a); }
.sa-figure .rail-b .node .cap { color: var(--b); }
.sa-figure .rail-b .node .cap::before { background: var(--b); }
.sa-figure .node h4 { margin: 0 0 8px; font-size: 14px; font-weight: 600; line-height: 1.3; color: var(--ink); }
.sa-figure .node p { margin: 0 0 10px; font-size: 12.5px; color: var(--ink-2); line-height: 1.5; }
.sa-figure .kv { background: var(--code-bg); border-radius: var(--radius-sm); padding: 7px 9px; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 11px; line-height: 1.55; color: var(--ink-2); display: grid; grid-template-columns: auto 1fr; column-gap: 8px; row-gap: 2px; overflow-wrap: anywhere; }
.sa-figure .kv .k { color: var(--ink-4); }
.sa-figure .kv .v { color: var(--ink); }
.sa-figure .rail-a .kv .v b { color: var(--a); font-weight: 600; }
.sa-figure .rail-b .kv .v b { color: var(--b); font-weight: 600; }
.sa-figure .node .arrow { position: absolute; top: 50%; right: -7px; transform: translateY(-50%); width: 14px; height: 14px; z-index: 3; pointer-events: none; background: var(--card); display: flex; align-items: center; justify-content: center; }
.sa-figure .node .arrow svg { width: 12px; height: 12px; display: block; }
.sa-figure .rail-a .arrow path { stroke: var(--a); }
.sa-figure .rail-b .arrow path { stroke: var(--b); }
.sa-figure .result { display: flex; align-items: center; gap: 10px; padding: 11px 16px; background: var(--hair-2); border-top: 1px solid var(--hair); font-size: 12.5px; color: var(--ink-2); }
.sa-figure .result .badge { font-size: 10px; font-weight: 700; letter-spacing: 0.08em; text-transform: uppercase; color: var(--ok); padding: 3px 8px; border: 1px solid var(--ok); border-radius: 10px; background: var(--card); }
.sa-figure .caption { margin-top: 10px; font-size: 12.5px; color: var(--ink-3); text-align: center; font-style: italic; line-height: 1.5; }
@media (max-width: 720px) {
  .sa-figure .layers { display: none; }
  .sa-figure .rail { grid-template-columns: 36px 1fr; }
  .sa-figure .rail-chip { grid-row: span 4; border-right: 1px solid var(--hair); }
  .sa-figure .node { border-right: none; border-bottom: 1px solid var(--hair); min-height: 0; }
  .sa-figure .node:last-child { border-bottom: none; }
  .sa-figure .node::before { content: attr(data-layer); display: block; font-size: 10px; font-weight: 700; letter-spacing: 0.1em; text-transform: uppercase; color: var(--ink-4); margin-bottom: 4px; }
  .sa-figure .node .arrow { display: none; }
  .sa-figure .rail + .rail { border-top: 2px solid var(--hair); }
}
</style>
<div class="diagram">
<div class="layers">
<div class="cell"></div>
<div class="cell"><div class="tag">Layer 1 · GPO</div><div class="name">Endpoint Routing</div><div class="mech">Workspace App → store URL</div></div>
<div class="cell"><div class="tag">Layer 2 · StoreFront</div><div class="name">Keyword Filter</div><div class="mech">Store shows one keyword only</div></div>
<div class="cell"><div class="tag">Layer 3 · Citrix Studio</div><div class="name">VDA Tag Match</div><div class="mech">Broker pins session to tagged VDA</div></div>
<div class="cell"><div class="tag">Layer 4 · GPO</div><div class="name">FSLogix Profile</div><div class="mech">Per-worker VHD location</div></div>
</div>
<div class="rail rail-a">
<div class="rail-chip"><span>A</span></div>
<div class="node" data-layer="Layer 1 · Endpoint Routing">
<div class="cap">Endpoint Group A</div>
<h4>Routed to Store A</h4>
<p>Workspace App config applied by GPO filtered on computer OU.</p>
<div class="kv"><span class="k">url</span><span class="v">…/Citrix/<b>StoreA</b></span></div>
<div class="arrow"><svg viewBox="0 0 12 12"><path d="M1 6 H10 M7 3 L10 6 L7 9" fill="none" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg></div>
</div>
<div class="node" data-layer="Layer 2 · Keyword Filter">
<div class="cap">Store A</div>
<h4>Enumerates only<br/>WorkerGroup-A resources</h4>
<p>Resources without this keyword are invisible to users of Store A.</p>
<div class="kv"><span class="k">keyword</span><span class="v"><b>WorkerGroup-A</b></span></div>
<div class="arrow"><svg viewBox="0 0 12 12"><path d="M1 6 H10 M7 3 L10 6 L7 9" fill="none" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg></div>
</div>
<div class="node" data-layer="Layer 3 · VDA Tag Match">
<div class="cap">VDAs · Tag A</div>
<h4>Single Delivery Group, per-VDA tag</h4>
<p>Broker only considers workers whose tag matches the keyword.</p>
<div class="kv"><span class="k">Worker-01</span><span class="v">tag: <b>WorkerGroup-A</b></span><span class="k">Worker-02</span><span class="v">tag: <b>WorkerGroup-A</b></span></div>
<div class="arrow"><svg viewBox="0 0 12 12"><path d="M1 6 H10 M7 3 L10 6 L7 9" fill="none" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg></div>
</div>
<div class="node" data-layer="Layer 4 · FSLogix Profile">
<div class="cap">Profiles A</div>
<h4>Per-worker OU, isolated VHD</h4>
<p>FSLogix <span class="mono">VHDLocations</span> is unique per worker — no shared profile storage.</p>
<div class="kv"><span class="k">W-01</span><span class="v">\\srv\profiles\<b>worker01</b></span><span class="k">W-02</span><span class="v">\\srv\profiles\<b>worker02</b></span></div>
</div>
</div>
<div class="rail rail-b">
<div class="rail-chip"><span>B</span></div>
<div class="node" data-layer="Layer 1 · Endpoint Routing">
<div class="cap">Endpoint Group B</div>
<h4>Routed to Store B</h4>
<p>Same mechanism, different OU — endpoints never configure themselves.</p>
<div class="kv"><span class="k">url</span><span class="v">…/Citrix/<b>StoreB</b></span></div>
<div class="arrow"><svg viewBox="0 0 12 12"><path d="M1 6 H10 M7 3 L10 6 L7 9" fill="none" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg></div>
</div>
<div class="node" data-layer="Layer 2 · Keyword Filter">
<div class="cap">Store B</div>
<h4>Enumerates only<br/>WorkerGroup-B resources</h4>
<p>Store B users can't see — let alone launch — a WorkerGroup-A resource.</p>
<div class="kv"><span class="k">keyword</span><span class="v"><b>WorkerGroup-B</b></span></div>
<div class="arrow"><svg viewBox="0 0 12 12"><path d="M1 6 H10 M7 3 L10 6 L7 9" fill="none" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg></div>
</div>
<div class="node" data-layer="Layer 3 · VDA Tag Match">
<div class="cap">VDAs · Tag B</div>
<h4>Same Delivery Group, different tag</h4>
<p>Tags alone carve the worker subset — no parallel Delivery Group needed.</p>
<div class="kv"><span class="k">Worker-03</span><span class="v">tag: <b>WorkerGroup-B</b></span><span class="k">Worker-04</span><span class="v">tag: <b>WorkerGroup-B</b></span></div>
<div class="arrow"><svg viewBox="0 0 12 12"><path d="M1 6 H10 M7 3 L10 6 L7 9" fill="none" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg></div>
</div>
<div class="node" data-layer="Layer 4 · FSLogix Profile">
<div class="cap">Profiles B</div>
<h4>Per-worker OU, isolated VHD</h4>
<p>Profile conflicts impossible by construction — every worker has its own store.</p>
<div class="kv"><span class="k">W-03</span><span class="v">\\srv\profiles\<b>worker03</b></span><span class="k">W-04</span><span class="v">\\srv\profiles\<b>worker04</b></span></div>
</div>
</div>
<div class="result">
<span class="badge">Result</span>
<span>Each account group is permanently bound to its own worker set — no cross-contamination, one Delivery Group.</span>
</div>
</div>
<div class="caption">Full architecture diagram showing the four-layer session affinity solution.</div>
</div>

Here's how I built it using only native Citrix features:

### Layer 1 - Endpoint Routing via GPO

I configured Citrix Workspace App via Group Policy to point each endpoint group to a **dedicated StoreFront store URL**.

- Endpoint Group A → `https://storefront.company.com/Citrix/StoreA`
- Endpoint Group B → `https://storefront.company.com/Citrix/StoreB`

GPO filtering based on computer OU or security group applied the correct Workspace App settings automatically. Endpoints never needed manual configuration.

### Layer 2 - StoreFront Keyword Filtering

In Citrix Studio, I added **Keywords** to the published applications/desktops. In the StoreFront stores, I configured each store to only display resources matching a specific keyword.

- Store A only shows resources tagged with keyword `WorkerGroup-A`
- Store B only shows resources tagged with keyword `WorkerGroup-B`

This means users connecting through Store A can only ever see and launch resources destined for Worker Group A. Cross-contamination at the enumeration level is impossible.

### Layer 3 - Citrix Tags on Individual Workers

Here's the part that kept the solution simple. Multiple Delivery Groups was the first shape the solution wanted to take. I ruled it out quickly - not because it wouldn't work technically, but because it would create something the ops team couldn't reason about. One Delivery Group with tagged VDAs is something you can explain in two sentences. So rather than creating multiple Delivery Groups, I **tagged each VDA individually** in Citrix Studio and used a **single Delivery Group**.

- Worker-01 → Tag: `WorkerGroup-A`
- Worker-02 → Tag: `WorkerGroup-A`
- Worker-03 → Tag: `WorkerGroup-B`
- Worker-04 → Tag: `WorkerGroup-B`

The combination of the keyword on the published resource and the tag on the VDA ensures the Delivery Controller routes sessions to the correct worker every time. One Delivery Group. No custom brokering logic. No code.

### Layer 4 - FSLogix Profile Separation via GPO

To prevent profile conflicts, I organised the VDA servers into separate OUs in Active Directory and applied **worker-specific GPOs** setting unique FSLogix `VHDLocations` paths per worker:

- Worker-01 → `\\srv\profiles\worker01`
- Worker-02 → `\\srv\profiles\worker02`
- Worker-03 → `\\srv\profiles\worker03`
- Worker-04 → `\\srv\profiles\worker04`

Each worker maintains completely isolated profile storage, regardless of which account connects.

## The Result

The solution was deployed to production and immediately resolved the application conflicts. The non-personalised account model was preserved entirely. The customer avoided the six-figure licensing cost they had been facing.

The whole thing was built using **native Citrix features** - no custom development, no major architecture changes, no new licences.

One final touch: I documented the solution thoroughly for the operations team, including a tip that's easy to miss - **enable the Tags column in Citrix Studio's Machine Catalogs view** so the ops team can see which workers carry which tags when troubleshooting. Without that, the routing logic is invisible to anyone maintaining the environment.

## Key Takeaways

**Sometimes the elegant solution is the simple one.** Multiple vendors said this required custom development. It didn't. It required understanding how StoreFront keywords and Citrix tags interact - and using them together intentionally.

**One Delivery Group is enough.** There's a temptation to create separate Delivery Groups for each worker group. Unnecessary. Tag the VDAs individually, use a single Delivery Group, and let the keyword + tag combination handle the routing.

**Document for the ops team, not just for yourself.** A solution is only good if the team maintaining it can understand and troubleshoot it. The Tags column tip in Studio is a small thing - but it's the difference between an ops engineer diagnosing a routing issue in two minutes versus two hours.

---

<br>

*Have you used StoreFront keywords in a similar way? I'd be interested to hear other creative uses of this feature - reach out on [LinkedIn](https://www.linkedin.com/in/robertmagasi/).*

<br>

> *This post was written with assistance from Claude (Anthropic) as a drafting and editing tool. All technical content, solutions, and recommendations reflect my own hands-on experience and professional judgment.*
