# Blog setup & configuration

**Site:** [robertmagasi.com](https://robertmagasi.com) — *EUC Insights by Robert*
**Repo:** [`rmagasi/rmagasi.github.io`](https://github.com/rmagasi/rmagasi.github.io)
**Author:** Robert Magasi
**Last updated:** 2026-04-17

Internal reference doc for how the blog is built, customised, deployed, and edited. Safe to commit — no secrets, tokens, or private URLs. The `docs/` folder is in `_config.yml`'s `exclude:` list, so this file is never published to the site.

---

## Table of contents

1. [Overview](#1-overview)
2. [Stack](#2-stack)
3. [Repository layout](#3-repository-layout)
4. [`_config.yml` essentials](#4-_configyml-essentials)
5. [Writing a post](#5-writing-a-post)
6. [Customizations](#6-customizations)
   1. [`metadata-hook.html` — the customization hub](#61-metadata-hookhtml--the-customization-hub)
   2. [`footer.html` override](#62-footerhtml-override)
   3. [`_layouts/post.html` override](#63-_layoutsposthtml-override)
   4. [`_sass/addon/custom.scss`](#64-_sassaddoncustomscss)
   5. [`_plugins/posts-lastmod-hook.rb`](#65-_pluginsposts-lastmod-hookrb)
7. [Comment system (Giscus)](#7-comment-system-giscus)
8. [Analytics (GoatCounter)](#8-analytics-goatcounter)
9. [Contact form](#9-contact-form)
10. [Data files](#10-data-files)
11. [Tab pages](#11-tab-pages)
12. [GitHub Actions workflows](#12-github-actions-workflows)
13. [The custom post editor](#13-the-custom-post-editor)
14. [GitHub App for editor auth](#14-github-app-for-editor-auth)
15. [Cloudflare Worker (CORS relay)](#15-cloudflare-worker-cors-relay)
16. [`robots.txt` override](#16-robotstxt-override)
17. [Known quirks & troubleshooting](#17-known-quirks--troubleshooting)
18. [File inventory](#18-file-inventory)

---

## 1. Overview

A Jekyll site built on the [Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) theme, deployed to GitHub Pages via a GitHub Actions workflow. Content is authored either directly in markdown or through a custom single-file HTML editor at `/editor/` that writes to the repo using the GitHub Contents API.

The site is intentionally simple to run: no database, no server, no third-party CMS. Only external services are Giscus (comments, backed by GitHub Discussions), GoatCounter (cookieless analytics), Formspree (contact form relay), and Cloudflare Workers (CORS relay for the editor's OAuth flow). All four have free tiers that comfortably cover this site.

The editor replaces a PAT-based auth flow with a GitHub App + Device Code OAuth. See sections 13–15.

---

## 2. Stack

| Layer | Choice | Notes |
|-------|--------|-------|
| Hosting | GitHub Pages | Custom domain `robertmagasi.com` via `CNAME` |
| Generator | Jekyll 4.x | Ruby 3.3 |
| Theme | [Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) ~> 7.4.1 | Installed as a gem, not forked |
| Comments | [Giscus](https://giscus.app) | Repo `Announcements` category |
| Analytics | [GoatCounter](https://www.goatcounter.com/) | Cookieless, no banner required |
| Contact form | [Formspree](https://formspree.io) | Free tier, 50 submissions/month |
| CI/CD | GitHub Actions | 3 workflows: deploy, schedule-publish, preview-draft |
| Editor | Single-file HTML at `/editor/` | Auth via GitHub App device flow |
| Editor relay | Cloudflare Worker | CORS shim for GitHub OAuth endpoints |

---

## 3. Repository layout

```
.
├── CNAME                         # robertmagasi.com custom domain
├── Gemfile                       # jekyll-theme-chirpy ~> 7.4.1 + html-proofer
├── _config.yml                   # site config (see §4)
├── _data/
│   ├── authors.yml               # robert → name, url, avatar
│   ├── contact.yml               # sidebar contact icons
│   └── share.yml                 # social share buttons on posts
├── _drafts/
│   └── post-template.md          # starting template for new posts
├── _includes/
│   ├── footer.html               # custom footer (§6.2)
│   ├── metadata-hook.html        # all custom CSS/JS (§6.1) — the big one
│   └── comments/
│       └── giscus.html           # custom Giscus with theme-sync (§7)
├── _layouts/
│   └── post.html                 # override of Chirpy's post layout (§6.3)
├── _plugins/
│   └── posts-lastmod-hook.rb     # git-based last_modified_at (§6.5)
├── _posts/                       # published posts (YYYY-MM-DD-slug.md)
├── _sass/addon/
│   └── custom.scss               # intentionally empty (§6.4)
├── _tabs/
│   ├── about.md                  # /about/
│   ├── archives.md               # Chirpy default
│   ├── blogroll.md               # curated EUC blogs
│   ├── categories.md             # Chirpy default
│   ├── contact.md                # contact form
│   ├── disclaimer.md             # legal
│   ├── impressum.md              # legal (required in .de/.ch)
│   ├── privacy-policy.md         # legal
│   └── tags.md                   # Chirpy default
├── assets/
│   ├── img/                      # avatar, OG images, post screenshots, favicons
│   ├── scripts/                  # downloadable scripts referenced in posts
│   ├── css/                      # any extra CSS
│   └── lib/                      # vendored libs
├── docs/                         # internal docs (this file) — excluded from build
├── editor/                       # deployed copy of the custom editor (§13)
├── robots.txt                    # override to disallow /editor/ (§16)
├── index.html                    # Chirpy's home — untouched
└── .github/workflows/
    ├── pages-deploy.yml          # build + htmlproofer + deploy (§12.1)
    ├── schedule-publish.yml      # daily 06:00 UTC draft promoter (§12.2)
    └── preview-draft.yml         # on-push non-main build (§12.3)
```

---

## 4. `_config.yml` essentials

Deviations and locally important keys:

| Key | Value | Why |
|-----|-------|-----|
| `theme` | `jekyll-theme-chirpy` | Gem-based, not `remote_theme` — required for Chirpy's JS bundling |
| `lang` | `en` | Matches `_data/locales/en.yml` in the theme gem |
| `timezone` | `Europe/Zurich` | Affects scheduled post display and feed timestamps |
| `title` | `Robert Magasi` | |
| `tagline` | `EUC Insights by Robert` | Shown as subtitle |
| `url` | `https://robertmagasi.com` | No trailing slash — used by `absolute_url` filter |
| `social.name` | `Robert Magasi` | Default post author, footer copyright owner |
| `social.links` | `[linkedin]` | First element becomes the copyright link |
| `webmaster_verifications` | Google + Bing set | Search Console / Webmaster Tools |
| `analytics.goatcounter.id` | `robertmagasi` | Subdomain at `robertmagasi.goatcounter.com` |
| `pageviews.provider` | `goatcounter` | Shows per-post view count on each post |
| `avatar` | `/assets/img/avatar.jpg` | Sidebar avatar |
| `social_preview_image` | `/assets/img/og_image.png` | Site-wide OG fallback |
| `toc` | `true` | Global default — can be overridden per-post |
| `comments.provider` | `giscus` | See §7 |
| `comments.giscus.repo` | `rmagasi/rmagasi.github.io` | |
| `comments.giscus.category` | `Announcements` | GitHub Discussions category |
| `comments.giscus.mapping` | `pathname` | Ties a discussion to `/posts/<slug>/` |
| `comments.giscus.input_position` | `top` | Comment box above the comment thread |
| `pwa.enabled` | `true` | Installable; `cache.enabled: false` (serve fresh) |
| `paginate` | `10` | Home page chunk size |
| `kramdown.syntax_highlighter` | `rouge` | Default; `block.line_numbers: true` |
| `defaults[_posts].comments` | `true` | Override with `comments: false` in front matter |
| `defaults[_posts].toc` | `true` | |
| `defaults[_drafts].comments` | `false` | Drafts never carry the giscus widget |
| `sass.style` | `compressed` | Required for Chirpy |
| `compress_html` | all | **Important** — breaks `//` inline comments (see §17) |
| `exclude` | `docs`, `tools`, `README.md`, `LICENSE` | `docs/` is where this file lives |
| `jekyll-archives.enabled` | `[categories, tags]` | Generates `/categories/<name>/` and `/tags/<name>/` |

---

## 5. Writing a post

### Front matter template

See [`_drafts/post-template.md`](../_drafts/post-template.md). The template carries every field the editor and CI expect:

```yaml
---
title: "Post title"
description: "160-char meta description for SEO and the card under the title"
date: 2026-04-17 10:00:00 +0200
categories: [Citrix]          # or [Azure], [Microsoft], [Meta], etc.
tags: [netscaler, saml]       # lowercase, hyphenated
author: robert                # keys in _data/authors.yml
image:
  path: /assets/img/posts/og-slug.png
  alt:  "Preview image alt text"
pin: false                    # pin to top of home
math: false                   # load MathJax only if needed
mermaid: false                # load mermaid only if needed
media_subpath: /assets/img/posts/   # optional per-post image root
---
```

### Drafts vs. published

- Files in `_drafts/` never render publicly. The `schedule-publish` workflow promotes them to `_posts/` on the day their front-matter `date:` falls due (see §12.2).
- Files in `_posts/` must be named `YYYY-MM-DD-slug.md`. The date in the filename must match the front-matter `date:` or Jekyll complains.
- The `permalink` default is `/posts/:title/` — the slug comes from the front-matter title, not the filename. Changing a title after publication breaks inbound links — avoid.

### Images

- Post OG images go in `assets/img/posts/og-<slug>.png`, sized 1200×630 at 2× retina (2400×1260 source, exported at 50%).
- Inline screenshots and diagrams also live under `assets/img/posts/`. Use `media_subpath` in front matter to keep markdown paths clean.
- The editor handles image uploads for OG images; everything else is committed manually.

### Categories vs. tags

- **Categories** are a small, controlled set — current: Citrix, Azure, Microsoft, Meta. Title-cased.
- **Tags** are open, granular, and lowercase-hyphenated: `netscaler`, `saml`, `entra-id`, `las-2026`.
- Chirpy uses `categories` for the sidebar navigation breadcrumb; `tags` show at the bottom of each post.

---

## 6. Customizations

### 6.1 `metadata-hook.html` — the customization hub

Location: [`_includes/metadata-hook.html`](../_includes/metadata-hook.html)

Chirpy reserves exactly one include file for user-injected head content: `metadata-hook.html`. The theme ships it empty; we replace it. **All site-wide custom CSS and JS lives in this file.** SCSS in `_sass/addon/custom.scss` is ignored when Chirpy is consumed as a gem — putting custom CSS there silently does nothing. That is the single most surprising thing about customizing gem-based Chirpy.

What this file contains (in order):

1. **Dynamic document title for non-home pages** — small JS that tweaks `<title>` so category/tag landing pages read "Tag: X · EUC Insights" instead of the Chirpy default.
2. **highlight.js imports (gated)** — light and dark CSS imported from CDN, toggled by the JS theme watcher below. Keeps the default rouge/Chirpy highlighting for most languages but allows PowerShell highlighting to kick in (see #4).
3. **PowerShell syntax highlighting CSS** — custom token colours for both light and dark. Overrides rouge's default palette for `ps1` / `powershell` code blocks.
4. **PowerShell syntax highlighter (JS)** — runs after load, finds `language-powershell` blocks produced by rouge (including the `<table>` / `.lineno` wrapper pattern rouge uses with line numbers on), and rewrites token classes so the CSS in #3 applies. Rouge's built-in PowerShell lexer is weak; this layer compensates.
5. **CSV cell highlighting** — colour-codes CSV header rows, cell values, and comma separators for both light and dark mode. Targets `language-csv` blocks.
6. **GoatCounter pageview badge styling + repositioning** — floats the pageviews counter to the top-right of `.post-meta` on each post, styles the inline loading spinner.
7. **Post preview image aspect-ratio fix** — forces 40:21 aspect ratio on `.preview-img` so Chirpy's home-page thumbnails don't jump between portrait and landscape.
8. **VS Code-style code block headers** — adds a subtle blue top border + language badge + copy button styling to code fences. Makes snippets feel native to developers reading the blog.
9. **Site footer styles** — small tweaks to the custom footer (see §6.2).
10. **About page author card styles** — the avatar-plus-name card at the top of `/about/`.
11. **Contact form styles** — form field styling, status message states (neutral / success / error), honeypot hiding (§9).
12. **Dark-mode theme switcher JS** — a `MutationObserver` on `<html data-mode>` that toggles highlight.js light/dark sheets and messages Giscus when the theme changes.

This file is ~180 lines of HTML/CSS/JS. Keep additions here unless you have a strong reason to go elsewhere.

### 6.2 `footer.html` override

Location: [`_includes/footer.html`](../_includes/footer.html) (12 lines).

Chirpy's default footer is replaced with a three-line block:

1. `© 2026 Robert Magasi` — copyright owner (pulled from `site.social.name`)
2. A one-line disclaimer: *"Views expressed are my own and do not represent my employer."*
3. Inline links — [Privacy Policy](/privacy-policy/) · [Disclaimer](/disclaimer/) · [Impressum](/impressum/) · [RSS](/feed.xml)

Rendered styles for the footer come from `metadata-hook.html` under the "Site footer styles" block (§6.1).

### 6.3 `_layouts/post.html` override

Location: [`_layouts/post.html`](../_layouts/post.html).

This is a near-verbatim copy of Chirpy's stock `post.html`, included in the repo so future overrides have a place to live. Current diffs from the stock file:

- The `preview-img` block hardcodes `w="1200" h="630"` so the home-page thumbnails match the OG image aspect ratio (otherwise Chirpy picks up the natural image dimensions and renders portrait images as tall, jumpy cards).

Everything else — author block, categories/tags, TOC, sharing buttons, related posts — is stock Chirpy.

### 6.4 `_sass/addon/custom.scss`

Intentionally empty with a single-line comment: *"Styles are injected via `_includes/metadata-hook.html`"*.

Why: in gem-based Chirpy, the theme's main SCSS entry point doesn't `@import` user files from `_sass/addon/`. The file exists only so future me doesn't delete it and then try to add styles there, expecting them to compile. The comment is a signpost. **Do not add styles here.**

### 6.5 `_plugins/posts-lastmod-hook.rb`

Location: [`_plugins/posts-lastmod-hook.rb`](../_plugins/posts-lastmod-hook.rb).

A 14-line Jekyll plugin that hooks `:posts` at `:post_init` and sets `post.data['last_modified_at']` to the ISO date of the most recent git commit that touched the file — but only if the file has more than one commit. This is what makes the "Updated" timestamp appear under posts that have been edited post-publish. If there's only one commit (the initial write), no "Updated" line is shown.

Requires git history to be present in the CI checkout. `pages-deploy.yml` sets `fetch-depth: 0` for this reason.

---

## 7. Comment system (Giscus)

Location: [`_includes/comments/giscus.html`](../_includes/comments/giscus.html).

Chirpy has a built-in Giscus include; we override it for two reasons:

1. **Theme sync** — when the site theme changes (user clicks the light/dark toggle), we `postMessage()` the Giscus iframe so the comments reflow to match. The stock Chirpy include doesn't do this reliably.
2. **Correct initial theme detection** — we check `<html data-mode>` first, fall back to `prefers-color-scheme`, then default to `light`. Ensures the iframe boots in the right theme on first load, not just after a toggle.

Giscus identity is set in `_config.yml` under `comments.giscus.*`:

- `repo: rmagasi/rmagasi.github.io`
- `repo_id: R_kgDORnNHRw`
- `category: Announcements` (GitHub Discussion category)
- `category_id: DIC_kwDORnNHR84C4Z0c`
- `mapping: pathname` — one discussion thread per `/posts/<slug>/` URL
- `input_position: top` — new comment box above the thread (UX preference)

**To disable comments on a specific post:** add `comments: false` to its front matter.

**To wipe and restart:** delete the discussion in the repo's Discussions tab. Giscus auto-creates a new one on first comment.

---

## 8. Analytics (GoatCounter)

- Provider: [GoatCounter](https://www.goatcounter.com)
- Account subdomain: `robertmagasi.goatcounter.com`
- Site ID: `robertmagasi` (set in `_config.yml → analytics.goatcounter.id`)
- Pageviews badge: enabled via `pageviews.provider: goatcounter` — Chirpy then shows per-post view counts fetched live from GoatCounter's public counter API.
- **Custom styling + repositioning** for the pageviews badge lives in `metadata-hook.html` (see §6.1 item 6). Default Chirpy placement was cramped; the override floats it to the top-right of the post header.

GoatCounter is cookieless by design, so no cookie banner is required under EU/Swiss privacy law.

---

## 9. Contact form

Location: [`_tabs/contact.md`](../_tabs/contact.md).

- **Backend:** Formspree endpoint `https://formspree.io/f/xlgpwpow`.
- **Method:** AJAX POST — the inline script intercepts the form `submit`, posts via `fetch()` with `Accept: application/json`, and renders a success/error message inline without a page reload.
- **Honeypot:** a hidden `<input name="_gotcha">` field. Formspree drops submissions where this field is filled (bots usually fill every field).
- **Accessibility:** status div uses `role="status"` and `aria-live="polite"` so screen readers announce the result.
- **Styles:** all form, label, status, and honeypot-hiding styles live in `metadata-hook.html` (§6.1 item 11).

**Rate limiting** is handled by Formspree (free tier = 50 submissions/month). If that starts filling, either upgrade or switch to self-hosted (a 10-line Cloudflare Worker would do it).

---

## 10. Data files

### `_data/authors.yml`

```yaml
robert:
  name: Robert Magasi
  url: https://www.linkedin.com/in/robertmagasi/
  avatar: /assets/img/avatar.jpg
```

Referenced from post front matter as `author: robert`. Chirpy then looks up the entry here. The `_layouts/post.html` template renders `name` inside an `<a href="url">` in the post meta.

### `_data/contact.yml`

Sidebar contact icons. Current entries: LinkedIn, GitHub, email, RSS. Twitter is commented out. The `email` type with `noblank: true` makes the link open in the current tab (so Outlook doesn't pop a new browser tab when clicked).

To add a new icon: copy one of the entries, pick the Font Awesome class from [fontawesome.com](https://fontawesome.com/), set the URL.

### `_data/share.yml`

Active share buttons under each post: Twitter (X), Facebook, Telegram, LinkedIn, Reddit. Mastodon, Weibo, Bluesky, Threads are commented-out stubs for future use. The `link:` field is a URL template — Chirpy substitutes `TITLE` and `URL` at render time.

---

## 11. Tab pages

The sidebar navigation entries on the left of every Chirpy page. Each is a markdown file in `_tabs/` with `order:` front matter controlling sort order. Current navigation (sorted by `order`):

| File | Path | Purpose |
|------|------|---------|
| `archives.md` | `/archives/` | Chirpy default — post list by year |
| `categories.md` | `/categories/` | Chirpy default — post list by category |
| `tags.md` | `/tags/` | Chirpy default — tag cloud |
| `about.md` | `/about/` | About the author + author card (§6.1 item 10) |
| `blogroll.md` | `/blogroll/` | Curated list of other EUC/Citrix blogs |
| `contact.md` | `/contact/` | Contact form (§9) |

Legal footer pages (linked only from the footer, not the sidebar):

| File | Path | Purpose |
|------|------|---------|
| `disclaimer.md` | `/disclaimer/` | "Views are my own" disclaimer |
| `impressum.md` | `/impressum/` | Legally required in CH/DE/AT |
| `privacy-policy.md` | `/privacy-policy/` | GDPR/DSG privacy statement |

Legal pages all have `icon: fas fa-...` set so Chirpy doesn't throw, but `order: 99+` or unset — they don't appear in the sidebar, only in the footer links.

---

## 12. GitHub Actions workflows

All three workflows live under `.github/workflows/`.

### 12.1 `pages-deploy.yml` — build + htmlproofer + deploy

Trigger: push to `main`, or manual `workflow_dispatch`.

Steps:
1. Checkout with `fetch-depth: 0` (required for `posts-lastmod-hook.rb` to read git history).
2. Setup Pages + Ruby 3.3 (cached via `bundler-cache: true`).
3. `bundle exec jekyll b -d _site<base_path>` with `JEKYLL_ENV: production`.
4. **htmlproofer** — validates internal links and absent `alt` attributes. Flags: `--disable-external` (skip hitting the internet), `--ignore-missing-alt` (Chirpy's own UI chrome has a few known gaps), `--ignore-files "/.+\.(png|jpg|jpeg|gif|webp|svg|ico)/"` (skip binary files).
5. Upload `_site` as a Pages artifact.
6. Deploy to GitHub Pages in the `github-pages` environment.

Concurrency group is `pages` with `cancel-in-progress: true` — if you push twice fast, only the last build deploys.

### 12.2 `schedule-publish.yml` — draft promoter

Trigger: daily at `06:00 UTC` (= 07:00 CET / 08:00 CEST), or manual.

Behaviour:
1. Checks `_drafts/*.md` for files whose front-matter `date:` is today or earlier.
2. Moves each matching file from `_drafts/` to `_posts/`, renaming it to the Chirpy `YYYY-MM-DD-slug.md` convention (using the date from the front matter, not the filename).
3. Commits with a message listing all promoted files.
4. Pushes to `main`.
5. `pages-deploy.yml` picks up the push and builds.

Safe to run multiple times per day (idempotent — nothing to promote = no commit). Handles quoted and unquoted YAML date values. Skips files with missing or unparseable dates with a GitHub notice.

To schedule a post: set its `date:` to a future day, save in `_drafts/`, commit, push. The workflow handles the rest.

### 12.3 `preview-draft.yml` — non-main branch preview

Trigger: push to any branch other than `main`/`master`/`gh-pages`.

Purpose: the editor has a local Chirpy-ish preview, but it's approximate. When you want to confirm *exactly* how a post will render, push to a branch. This workflow runs the same Chirpy build as production (with `JEKYLL_ENV: production`) and uploads the resulting `_site/` as a workflow artifact you can download, unzip, and open locally.

Why not a live URL? GitHub Pages serves one site per repo. Per-branch URLs would need a second host (Netlify, Cloudflare Pages). The artifact-download approach catches ~90% of render drift at zero extra cost.

The workflow also posts a summary listing the changed markdown files vs. `main`, so the PR reviewer (you) knows what's new.

---

## 13. The custom post editor

Location in repo: [`editor/index.html`](../editor/index.html).
Source of truth (where edits are made): `/sessions/focused-kind-turing/mnt/Cowork/index.html`.
Deployed URL: [`https://robertmagasi.com/editor/`](https://robertmagasi.com/editor/).

### Why a custom editor

Writing posts directly in markdown + committing by hand works but is slow. A dedicated UI:

- enforces the front-matter template (§5), so I stop forgetting fields;
- provides a live Chirpy-themed preview;
- holds unfinished work in **IndexedDB** so a browser crash doesn't lose draft text;
- commits to GitHub through the Contents API, no local git needed;
- can run from a static URL — no server.

### What's in the file

A single ~3,300-line HTML file containing:

- **Editor UI** — title, description, date, category, tags, pin/math/mermaid toggles, image path, markdown editor (CodeMirror-style behaviour) + split preview.
- **`YAML` module** — builds/parses the YAML front matter block. Stable key order, safe quoting, handles arrays and booleans.
- **`GH` module** — wraps the GitHub Contents API. Reads files, writes/commits files, handles branches, lists directories. Centralizes headers/auth (§14).
- **`Auth` module** — GitHub App device-flow OAuth (see §14). Handles token refresh, pre-emptive expiry, sign-out + revoke.
- **`Drafts` module** — IndexedDB-backed autosave. Every text change bounces into a debounced save; `Ctrl+K` opens a draft picker to resume any unfinished post.
- **`Preview` module** — markdown → HTML with marked.js, then injects Chirpy-ish CSS for the split-pane preview.
- **Settings modal** — repo/branch picker, OAuth sign-in or legacy PAT fallback, editor preferences.
- **Device-code modal** — when user clicks "Sign in with GitHub", shows the 8-char user code, a "Copy" button, and an "Open github.com/login/device" launcher. Polls until authorized or the code expires.

### Dual-auth transition state

The editor currently supports **both** authentication paths:

1. **Preferred:** GitHub App device-flow OAuth (see §14). Used if an access token exists in `localStorage`.
2. **Fallback:** Fine-grained Personal Access Token pasted into Settings. Used if no OAuth token is present. The PAT UI is collapsed under a "Legacy PAT" expander so it's available but not prominent.

This dual-mode exists so migration is non-breaking. The plan to remove PAT support entirely is in [`Cowork/github-app-migration-plan.md`](../../Cowork/github-app-migration-plan.md) (outside this repo).

### `/editor/` is excluded from crawlers

See §16 on `robots.txt`.

### Editor ↔ source sync

The editor source of truth lives outside this repo at `/sessions/focused-kind-turing/mnt/Cowork/index.html`. When a change is ready, it is copied to `editor/index.html` and committed. Future improvement: symlink or build step so the copies can't drift. Until then, always copy with PowerShell `Copy-Item` (preserves LF line endings — a Node/VS Code copy introduced a truncation once and caused a confusing "Settings button does nothing" incident).

---

## 14. GitHub App for editor auth

**Name:** RM Post Editor
**Client ID:** `Iv23liI9Pm1h68n6vsbu` (public — safe to commit, no secret)
**Installed on:** `rmagasi/rmagasi.github.io`
**Permissions:** Contents R/W, Metadata R
**Scope:** "Only on this account" — nobody else can install it
**Auth flow:** Device Code (no client secret, no callback URL needed)

### Why a GitHub App instead of a PAT

- Fine-grained PATs expire every 90 days. GitHub App user-to-server tokens refresh automatically.
- Tokens are short-lived (8 h) + refreshed in the background on 401.
- The app is installed per-repo — the browser client can never get a broader scope than what was installed.
- Revokable from `github.com/settings/apps/authorizations` with one click.
- Sharing the editor with a colleague eventually becomes possible without pasting tokens around (currently blocked because install scope is "only on this account" — can be relaxed later).

### Flow summary

1. User clicks "Sign in with GitHub" in Settings.
2. Editor `POST`s to Cloudflare Worker `/device/code` (§15), gets a `device_code` + `user_code` + verification URL.
3. Editor shows the `user_code` + a button that opens `github.com/login/device` in a new tab.
4. User types the code on GitHub and authorizes.
5. Meanwhile, editor polls the Worker's `/access_token` endpoint every ~5 s.
6. On success, editor receives an `access_token` (8 h) + `refresh_token` (~6 mo) + stores both in `localStorage` under keys `rm_access_token`, `rm_refresh_token`, `rm_token_expires`, `rm_refresh_expires`, `rm_auth_user`.
7. Every GitHub API call from the editor uses `Authorization: Bearer <access_token>`.
8. If a request returns 401, the editor automatically calls `/access_token` with the refresh token to get a new access token and retries the original request once.
9. On sign-out, the editor clears the storage keys (no server-side revoke call is made by default — the user can revoke manually at github.com if desired).

Full rationale and the original migration plan: [`Cowork/github-app-migration-plan.md`](../../Cowork/github-app-migration-plan.md).

---

## 15. Cloudflare Worker (CORS relay)

**URL:** `https://rm-gh-auth.robert-magasi.workers.dev`
**Source:** `/sessions/focused-kind-turing/mnt/Cowork/cloudflare-worker/worker.js`
**Cost:** free (Cloudflare Workers free tier: 100k req/day)

### Why this exists

GitHub's device-flow endpoints at `github.com/login/device/code` and `github.com/login/oauth/access_token` **do not set CORS headers**. Any browser-only editor (like ours) that tries to POST to them directly gets:

```
✗ Failed to fetch
CORS preflight rejected
```

The Worker is a three-endpoint proxy that forwards the same POSTs to GitHub and adds the missing CORS headers to the response. Nothing else.

### What it does

| Route | Action |
|-------|--------|
| `GET /` | Health check — returns `{ok: true, service: "rm-gh-auth", endpoints: [...]}` |
| `POST /device/code` | Forwards to `https://github.com/login/device/code`, returns with CORS headers |
| `POST /access_token` | Forwards to `https://github.com/login/oauth/access_token`, returns with CORS headers |
| `OPTIONS *` | CORS preflight response |

### Security considerations

- **No secrets stored** on the Worker. Device flow uses a public client ID only; no client secret exists for GitHub Apps using device flow.
- **Open relay** in the current configuration (`ALLOWED_ORIGINS = null`). Anyone hitting the URL can *start* a device flow for RM Post Editor, but because the app is installed "Only on this account," nobody else can actually get a usable token. The worst case is a random stranger sees the 8-char user code — harmless.
- **Origin allowlist** is supported in code (`ALLOWED_ORIGINS = new Set([...])`) and can be turned on if the editor ever moves to a single known origin.

### Deploy

1. Cloudflare dashboard → Workers & Pages → Create Worker.
2. Paste `worker.js` contents verbatim.
3. Click Save and Deploy.
4. Copy the `<worker-name>.<subdomain>.workers.dev` URL.
5. Update `AUTH.DEVICE_URL` and `AUTH.TOKEN_URL` in `editor/index.html` to point to it.

No state, no env vars, no bindings. Deploy-once, forget.

---

## 16. `robots.txt` override

Location: [`robots.txt`](../robots.txt) in repo root.

Chirpy ships its own `robots.txt` inside the gem. Placing a file of the same name in the site source overrides it. Full contents:

```
---
layout: null
---
User-agent: *

Disallow: /norobots/
Disallow: /editor/

Sitemap: {{ "/sitemap.xml" | absolute_url }}
```

- `layout: null` + the front-matter fence causes Jekyll to process the file (so the `{{ ... }}` Liquid tag resolves) but not wrap it in an HTML layout.
- `/editor/` is `Disallow`ed because there's no reason for Googlebot to index a 3,000-line editor UI — it produces no useful content for users landing from search, and slows down the crawl budget.
- `/norobots/` is a convention kept for ad-hoc "don't index this" pages.
- The sitemap line uses `absolute_url` so it resolves to `https://robertmagasi.com/sitemap.xml` (the sitemap is generated by `jekyll-sitemap`, bundled in the Chirpy gem).

Note: `Disallow` is advisory. A motivated crawler can still fetch `/editor/`. Real security for the editor comes from the GitHub App being installed "Only on this account" (§14) — even if a stranger loads the page and clicks Sign In, they cannot obtain a token with repo access.

---

## 17. Known quirks & troubleshooting

### "Styles in `_sass/addon/custom.scss` do nothing"

Because gem-based Chirpy doesn't `@import` from there. Put site-wide CSS in `_includes/metadata-hook.html`. See §6.4.

### "`//` comments in inline scripts break rendering"

`compress_html` (enabled in `_config.yml`) strips newlines aggressively and turns `// comment` into `// comment<next-line-of-code>`, commenting out the next line. **Always use `/* ... */` block comments inside `<script>` tags** if the script is inline. For external JS files it doesn't matter.

### "htmlproofer fails on `<img src="">`"

Happens when the editor's sign-in avatar image has no `src` before the user authenticates. Fix: add `data-proofer-ignore` to the `<img>` element. Already applied in both `Cowork/index.html` and `editor/index.html`.

### "Editor copy is truncated / Settings button does nothing"

Happened once when the editor was copied from the source via a path that silently converted LF → CRLF and lost ~120 lines off the end. Fix: use PowerShell `Copy-Item` (preserves line endings), and verify `wc -l` matches between source and destination before committing.

### "`We couldn't respond to your request in time` at `/login/device`"

GitHub's device-code / `/login` flow had a transient global outage on 2026-04-17. Worker tested fine (returned valid device codes). Not a site bug. If it happens again, check [githubstatus.com](https://www.githubstatus.com) before debugging locally.

### "Last modified date is wrong / missing"

Requires `fetch-depth: 0` in the GitHub Actions checkout. Already set in `pages-deploy.yml`. If last-modified dates ever disappear in production, the first thing to check is whether someone dropped `fetch-depth: 0` from the workflow.

### "htmlproofer flags LinkedIn / external URLs"

We use `--disable-external` to skip all external link checks. External link rot is frequent and would block deploys on unrelated failures. Internal links are still validated.

### "Giscus shows in the wrong theme"

The override in `_includes/comments/giscus.html` handles theme sync via `MutationObserver` on `<html data-mode>`. If you see theme mismatch, the order-of-load is usually the issue — make sure `metadata-hook.html` runs its theme detection before Giscus mounts. Both already run at end of `<head>` so this is rare.

### "Rouge PowerShell highlighting looks wrong"

The custom PowerShell highlighter in `metadata-hook.html` is layered on top of rouge's own output. If rouge is updated and changes its DOM structure, the highlighter may silently stop working. Test case: open `/posts/citrix-scheduled-reboot-script/` and confirm the `ps1` block shows colour-coded keywords, strings, and cmdlets.

---

## 18. File inventory

Quick reference of every non-default file, what it does, and whether it's safe to delete:

| File | Purpose | Safe to remove |
|------|---------|----------------|
| `_config.yml` | Site config | No |
| `Gemfile` / `Gemfile.lock` | Ruby deps | No |
| `CNAME` | Custom domain | No (breaks robertmagasi.com) |
| `robots.txt` | Crawler override (§16) | If removed, falls back to Chirpy default |
| `_data/authors.yml` | Author definitions | No (post layout reads it) |
| `_data/contact.yml` | Sidebar icons | Yes, but sidebar loses contact icons |
| `_data/share.yml` | Share buttons | Yes, but post tails lose share row |
| `_drafts/post-template.md` | Post template | Yes, but you lose your template |
| `_includes/footer.html` | Custom footer (§6.2) | If removed, falls back to Chirpy default |
| `_includes/metadata-hook.html` | All custom CSS/JS (§6.1) | No — removing breaks most customizations |
| `_includes/comments/giscus.html` | Giscus with theme-sync (§7) | If removed, falls back to Chirpy's stock Giscus (no theme sync) |
| `_layouts/post.html` | Post layout override (§6.3) | Yes, falls back to Chirpy default |
| `_plugins/posts-lastmod-hook.rb` | Git-based last_modified_at (§6.5) | Yes, posts lose "Updated" timestamp |
| `_sass/addon/custom.scss` | Intentional placeholder (§6.4) | Yes, but read the comment first |
| `_tabs/*.md` | Sidebar + legal pages (§11) | Only `about.md`, `blogroll.md`, `contact.md`, and legal pages are custom; `archives.md`, `categories.md`, `tags.md` are Chirpy defaults you can delete to use theme-provided versions |
| `assets/img/avatar.jpg` | Sidebar avatar | No |
| `assets/img/og_image.png` | Site-wide OG fallback | No |
| `assets/img/posts/og-<slug>.png` | Per-post OG images | Per-post |
| `editor/index.html` | Deployed editor copy (§13) | Yes, but you lose `/editor/` |
| `.github/workflows/pages-deploy.yml` | Build + deploy (§12.1) | No |
| `.github/workflows/schedule-publish.yml` | Draft promoter (§12.2) | Yes, but you lose scheduled publishing |
| `.github/workflows/preview-draft.yml` | Branch preview (§12.3) | Yes, but branch pushes no longer build |
| `docs/SETUP.md` | This file | Yes (docs/ is excluded from build anyway) |

---

## Appendix: tool links

- Giscus config wizard: <https://giscus.app>
- GoatCounter: <https://www.goatcounter.com/>
- Formspree dashboard: <https://formspree.io/forms>
- Font Awesome (for `_data/contact.yml` icons): <https://fontawesome.com>
- GitHub App management: <https://github.com/settings/apps>
- Cloudflare Workers dashboard: <https://dash.cloudflare.com>
- Chirpy theme docs: <https://chirpy.cotes.page/>
- Jekyll docs: <https://jekyllrb.com/docs/>
