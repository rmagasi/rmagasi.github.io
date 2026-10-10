---
title: "My Second Brain: Claude, Obsidian and Git"
date: 2026-09-21 09:00:00 +0200
last_modified_at: 2026-10-10 00:00:00 +0200
author: robert
categories: ["Meta", "AI"]
tags: ["obsidian", "claude", "ai", "knowledge-management", "git", "automation", "second-brain"]
description: "How I turn EUC troubleshooting sessions into a knowledge base that answers the next question. Three layers, a strict human gate, and why every note is plain markdown in git."
image:
  path: /assets/img/posts/og-second-brain-architecture.png
  alt: "Three layers of a second brain: structure, knowledge and procedure"
---

The oldest note in my vault is an FSLogix redirections.xml from October 2019. It spent six and a half years in OneNote, next to hundreds of other notes.

In April 2026 I moved all of it into plain markdown, for two reasons. I wanted it under git, and I wanted Claude to be able to read through it. That move was the start of what this post describes: a second brain.

The goal is not note-taking in general, and not productivity. One specific thing: turning work that already happened into the answer to the next question.

## Why EUC makes this harder than it sounds

Most knowledge-base advice assumes facts stay true. Ours do not.

What was correct for CVAD 1912 LTSR is wrong for 2402. An FSLogix recommendation from 2023 may be actively harmful now. NetScaler changed its own product name and back again. A note without a version and a date is worse than no note, because it reads as authoritative and is not.

So the system has to do three things a folder of markdown does not do on its own. It has to record *when* something was true. It has to let two notes disagree without one silently overwriting the other. And it has to stop me trusting anything that has not been checked by a human.

## Three layers

The whole thing is three separate things that people usually mash into one.

| Layer | What it holds | When it loads |
|---|---|---|
| **Structure** | Where things are and what state they are in | Every session |
| **Knowledge** | What is true, and when it was true | On demand |
| **Procedure** | How to read and write the other two | By trigger |

**Structure** is a thin index at the root of my projects folder, about 4 KB. It is deliberately small because it loads into every conversation I have with Claude, and anything in it is paid for in every session. Each project then has its own file with its current state, loaded only when that project is in play. Those have a 4 KB target too, and most of them are over it. The monthly maintenance task flags them, and trimming them is on me.

**Knowledge** is the Obsidian vault, about 390 notes. Around 165 of them are KB notes across Citrix, Microsoft, IGEL, VMware, Entrust and my homelab, about 105 are exam-prep notes, and the rest are career material, blog ideas and the vault's own maintenance records. This is the large one, and it is pulled in only when the topic calls for it.

**Procedure** is a private plugin marketplace. Skills that know how to write a note in my conventions, how to research a question against a tiered source list, and how to draft for this blog. Versioned separately, which means I can change the rules for writing a note without touching a single note.

The split matters more than any individual piece. Structure stays cheap enough to always have loaded. Knowledge stays out of the way until it is relevant. Procedure changes on its own schedule.

## How something gets in

Capture has to be nearly free or it does not happen during a working day. Four routes in:

- **Obsidian Web Clipper** drops articles into a `Clippings/` folder. That folder is a landing zone, not an archive.
- **Working sessions** with Claude where something non-obvious got solved.
- **Client engagements**, which produce the raw material.
- **Research**, against a curated source list rather than an open web search.

Two skills do the conversion. One turns a clipping, URL or PDF into a formatted, cross-linked KB note. The other takes the session I just finished and files it as a troubleshooting note or a runbook, capturing what was diagnosed, what I tried, what actually worked, and the commands, with client-identifying detail stripped.

Both treat the source as data, never as instruction. A fetched page that contains something resembling a command does not get to steer the process. That mattered more once I started ingesting arbitrary URLs.

## The gate

This is the part I would keep if I threw away everything else.

Every note written automatically lands at `maturity: seed`. Not `draft`, not `unreviewed`, a specific value with a specific meaning: *nothing has checked this except the thing that wrote it*.

This note started there, and I have since promoted it:

```yaml
---
title: Slow HDX connection phase from failed Rendezvous and EDT fallback
created: 2026-09-06 19:28:08
updated: 2026-09-06 19:28:08
source: cowork-session
type: troubleshooting
maturity: mature
product: citrix
severity: high
tags:
  - citrix
  - citrix-daas
  - rendezvous
  - hdx
---
```

The ladder is `seed`, `developing`, `mature`, `evergreen`. **Only I move a note up it.** No automation promotes anything, and the weekly maintenance task is explicitly forbidden from touching the field.

Without that rule, an AI-assisted knowledge base becomes a pile of plausible-looking text that you cannot distinguish from the parts you verified. With it, `seed` means "unverified, a lead worth following", `developing` means "reviewed, with gaps", and `mature` means "complete, for the version it names". Those are different claims and the vault keeps them apart.

`evergreen` is the interesting one. It means conceptual content that does not rot. Very little EUC material qualifies, which is itself worth knowing.

## Contradictions get flagged, not resolved

When a new source conflicts with an existing note, the convention is a callout on **both** pages, each naming the other and stating which product version it describes.

> Nothing overwrites. Two notes disagreeing is usually two correct notes about different releases, and collapsing them into one destroys the only useful part.

This is the convention I would most recommend to anyone doing the same thing in EUC. The instinct is to keep the knowledge base tidy by resolving conflicts. In a version-bound field, tidiness is how you lose the context that made the note worth keeping.

## How something comes back out

Retrieval is rationed on purpose. The documented order is the vault home page, then the relevant map-of-content index, then three to five notes. If I want ten, I picked the wrong index.

That constraint exists because the failure mode of a large vault plus an AI assistant is reading forty notes to answer a question that needed two. It is slow, it costs context, and the answer gets worse rather than better.

The loop closes by producing something outside the vault. Posts on this blog, client deliverables, and interview material. Knowledge that never leaves is a cost, not an asset.

## Why git, and why three repos

Everything is plain markdown in git. No proprietary format, no vendor, no sync service that can decide to change its terms.

Internal links are standard markdown with `%20` for spaces, never Obsidian wikilinks:

```markdown
[Citrix Worker Base](KB/Citrix/Policies/Citrix%20Worker%20Base.md)
```

Wikilinks render as literal text on GitHub. Plain links mean I can read the whole vault from any machine with a browser, including a locked-down client laptop where I am never going to install Obsidian. That single constraint has paid for itself more than any plugin.

Three repositories for the system itself, not one, because they change at completely different rates. The blog has a fourth repo of its own, but that is output, not part of the brain.

- The **vault** commits automatically every 30 minutes. I never think about it.
- The **structure layer** is manual, and it is small.
- The **skills** are manual and change rarely, because a procedure change is always deliberate.

Putting them together would mean either losing the vault's auto-commit or drowning the skills history in note edits.

## What keeps it honest

Two scheduled tasks. A weekly one lints the vault, applies safe mechanical fixes, checks links, reports orphaned notes, and lists which `seed` notes have been waiting for me. A monthly one keeps the structure layer accurate against what is actually on disk.

Neither is allowed to make an irreversible change unattended, and neither can promote a note. They surface work. I do it.

## What it costs, honestly

It is not free and it is not automated.

The promotion queue is a standing debt. Right now 13 notes sit at `seed`. None of them is older than two weeks, but that list only shrinks when I sit down and read them. An assistant that wrote *and* approved its own notes would be less work and worth much less.

The gate is also younger than the vault. Trust tracking only became mandatory in August 2026, and around 300 notes migrated from OneNote still carry no maturity at all. The weekly report counts them as an untyped backlog. They are not necessarily wrong, they are simply unrated.

Setup was real effort, spread over months rather than a weekend. And it is shaped around a field where facts expire. If you work somewhere the answer stays true for a decade, most of the machinery here is overhead you do not need.

What I get back is specific. A fix I solved once is findable again, with the version it applied to and the date it was filed. And the loop is short. This week a note about an IGEL OS 12 fix went into the vault and was a published post on this blog the same day.

## Related

- [Building This Blog With Claude AI](/posts/building-this-blog-with-claude-ai/) - the same working pattern applied to the site you are reading, including the custom post editor
- [IGEL OS 12 and Citrix: Post-Session Logoff Was the Wrong Fix](/posts/igel-os-12-citrix-soft-logoff/) - the vault note to published post loop described above, done in one day
- [HDX Connection Time, the Logon Phase You Should Be Checking](/posts/citrix-hdx-connection-time-rendezvous/) - the troubleshooting session behind it was filed in the vault the same day, the note shown above

---

<br>

*Describes the setup as it stood in October 2026, about 390 notes in.*

<br>

*Running something similar, or solved the version-drift problem a different way? I would like to hear it, reach out on [LinkedIn](https://www.linkedin.com/in/robertmagasi/).*

<br>

> *This post was written with assistance from Claude (Anthropic) as a drafting and editing tool. All technical content, solutions, and recommendations reflect my own hands-on experience and professional judgment.*
