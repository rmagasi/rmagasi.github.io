# Blog setup & configuration

**Site:** [robertmagasi.com](https://robertmagasi.com) — *EUC Insights by Robert*
**Repo:** [`rmagasi/rmagasi.github.io`](https://github.com/rmagasi/rmagasi.github.io)
**Author:** Robert Magasi
**Last updated:** 2026-11-22

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
16. [`robots.txt`](#16-robotstxt)
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
| CI/CD | GitHub Actions | 4 workflows: deploy, preview-draft, link-check, indexnow. Dependabot keeps actions and gems current |
| Static assets | Self-hosted | Fonts, icons and libraries from `assets/lib` (submodule) and `assets/highlightjs/`, no CDN on public pages |
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
│   ├── highlightjs/              # highlight.js 11.9.0, used for PowerShell blocks
│   └── lib/                      # chirpy-static-assets submodule, self-hosted fonts and libraries
├── docs/                         # internal docs (this file) — excluded from build
├── editor/                       # deployed copy of the custom editor (§13)
├── index.html                    # Chirpy's home — untouched
└── .github/
    ├── dependabot.yml            # monthly update PRs for actions and gems (§12.5)
    └── workflows/
        ├── pages-deploy.yml      # build + htmlproofer + deploy (§12.1)
        ├── link-check.yml        # weekly link check incl. external links (§12.2)
        ├── preview-draft.yml     # on-push non-main build (§12.3)
        └── indexnow.yml          # tells Bing and co. about changed posts (§12.4)
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

- Files in `_drafts/` never render publicly. Nothing promotes them automatically, a post goes live when the editor publishes it with destination Posts. The former `schedule-publish` workflow was removed on 2026-11-22. Drafts carry their planned publish date in the file name and the front matter, the `2099-12-31` hold date was dropped on 2026-11-25. The editor's Promote button copies a draft as it is, so a draft dated today or earlier goes live at once.
- Files in `_posts/` must be named `YYYY-MM-DD-slug.md`. The date in the filename must match the front-matter `date:` or Jekyll complains.
- The `permalink` default is `/posts/:title/` — the slug comes from the front-matter title, not the filename. Changing a title after publication breaks inbound links — avoid.

### Images

- Post OG images go in `assets/img/posts/og-<slug>.png`, sized 1200×630 at 2× retina (2400×1260 source, exported at 50%).
- Inline screenshots and diagrams also live under `assets/img/posts/`. Use `media_subpath` in front matter to keep markdown paths clean.
- The editor handles image uploads for OG images; everything else is committed manually.
- PNGs are stored as 256-colour palette files where that is visually lossless, about half the size. `scripts/compress_png.py` in the `euc-insights-blog` skill does it, `render_hero.py` and `generate_og.py` call it on their own.

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
2. **highlight.js imports** - light and dark CSS from `assets/highlightjs/` (self-hosted since Nov 2026), toggled by the JS theme watcher below. The two highlight.js scripts are only emitted on pages that contain a PowerShell block (`content contains 'language-powershell'`), the editor's site preview adds them itself when its template page has none.
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

All workflows live under `.github/workflows/`. Nothing publishes on a schedule, the only scheduled run is the link check.

### 12.1 `pages-deploy.yml` - build + htmlproofer + deploy

Trigger: push to `main`, or manual `workflow_dispatch`.

Steps:
1. Checkout with `fetch-depth: 0` (required for `posts-lastmod-hook.rb` to read git history) and `submodules: true` (`assets/lib` holds the self-hosted fonts and libraries, `assets.self_host.enabled` is `true` in `_config.yml`).
2. Setup Pages + Ruby 3.3 (cached via `bundler-cache: true`).
3. `bundle exec jekyll b -d _site<base_path>` with `JEKYLL_ENV: production`.
4. **htmlproofer** - validates internal links, scripts and images. Flags: `--disable-external` (skip hitting the internet), `--ignore-missing-alt` (Chirpy's own UI chrome has a few known gaps), `--ignore-files "/.+\.(png|jpg|jpeg|gif|webp|svg|ico)/"`.
5. Upload `_site` as a Pages artifact.
6. Deploy to GitHub Pages in the `github-pages` environment.

Concurrency group is `pages` with `cancel-in-progress: true` - if you push twice fast, only the last build deploys.

A push made by a workflow with the built-in `GITHUB_TOKEN` does **not** start this workflow. That is why the old scheduled publisher never deployed what it promoted.

### 12.2 `link-check.yml` - weekly link check

Trigger: Mondays (cron `23 4 * * 1`, GitHub often starts scheduled runs hours late), or manual.

Builds the site like the deploy workflow and runs htmlproofer on all links, external ones included. It changes nothing and deploys nothing, a failed run only sends the usual GitHub notification. Fix the link in the post, then re-run it from the Actions tab.

Not checked on purpose: the share buttons, LinkedIn and hattrick.org (both answer automated requests with an error), the editor page, and `429` answers.

This workflow replaced `schedule-publish.yml` as the only scheduled one. The scheduled publisher (daily promotion of due drafts) was removed on 2026-11-22: it had fired once in seven months, unintended, and its push never triggered a deploy.

### 12.3 `preview-draft.yml` - non-main branch preview

Trigger: push to any branch other than `main`/`master`/`gh-pages`. Dependabot branches count, so every update PR gets a build.

Runs the same Chirpy build as production (with `JEKYLL_ENV: production`) and uploads the resulting `_site/` as a zipped workflow artifact you can download and open locally. The artifact name carries the branch name with slashes replaced by dashes, artifact names must not contain a slash.

Why not a live URL? GitHub Pages serves one site per repo. Per-branch URLs would need a second host (Netlify, Cloudflare Pages).

### 12.4 `indexnow.yml` - search engine ping

Trigger: after a successful "Build and Deploy" run, or manual (with a "submit all posts" option).

Runs `tools/indexnow-submit.py`, which diffs the last two commits and submits the URLs of changed posts to IndexNow (Bing, Yandex, DuckDuckGo). The key file is `d3d07fc2675393a4c9805edc4eaccf2c.txt` in the repo root.

### 12.5 Dependabot

`.github/dependabot.yml` opens one grouped pull request per month for the workflow actions and one for the Ruby gems. Nothing merges on its own. `jekyll-theme-chirpy` is ignored there on purpose: theme upgrades are manual, because `_includes/head.html`, `_layouts/home.html`, `_layouts/post.html` and `_data/locales/en.yml` are full copies of theme files that have to be re-synced with every theme release.

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

### `/editor/` is kept out of search

The page carries `<meta name="robots" content="noindex, nofollow">` and is excluded from `sitemap.xml` through a `sitemap: false` default for `editor/` in `_config.yml`. It is deliberately not disallowed in `robots.txt`, see §16.

Its CDN libraries (EasyMDE, marked, js-yaml, diff, highlight.js, Font Awesome 4.7) are pinned to exact versions and carry integrity hashes, because the page works with a token that can write to the repo.

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

## 16. `robots.txt`

There is no local `robots.txt`. The live file is the one Chirpy ships (`assets/robots.txt` in the gem, with `permalink: /robots.txt`):

```
User-agent: *

Disallow: /norobots/

Sitemap: https://robertmagasi.com/sitemap.xml
```

A `robots.txt` in the repo root existed from May to November 2026 and never took effect: it collided with the theme's file, the theme's won, and the build only printed a "Conflict: The following destination is shared by multiple files" warning. To change the rules, override `assets/robots.txt` at exactly that path.

`/editor/` is not disallowed, and should not be. A crawler that may not fetch the page never sees its `noindex` tag, and a disallowed URL can still be listed in results without a snippet. Real protection for the editor comes from the GitHub App being installed "Only on this account" (§14).

`sitemap.xml` is generated by `jekyll-sitemap`. Two things are kept out of it: `editor/` (config default) and the tag archive pages, which are `noindex` (`_plugins/sitemap-exclude-tag-archives.rb`).

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

The deploy uses `--disable-external`, so external link rot never blocks a deploy. External links are checked once a week by `link-check.yml` (§12.2), which skips LinkedIn and the share buttons.

### "Local htmlproofer says success after 0.05 seconds"

It needs a UTF-8 locale. Without `LANG=C.UTF-8` it fails to parse every page, checks nothing and still reports success. A real run takes more than a second.

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
| `_data/authors.yml` | Author definitions | No (post layout reads it) |
| `_data/contact.yml` | Sidebar icons | Yes, but sidebar loses contact icons |
| `_data/share.yml` | Share buttons | Yes, but post tails lose share row |
| `_drafts/post-template.md` | Post template | Yes, but you lose your template |
| `_includes/footer.html` | Custom footer (§6.2) | If removed, falls back to Chirpy default |
| `_includes/metadata-hook.html` | All custom CSS/JS (§6.1) | No — removing breaks most customizations |
| `_includes/comments/giscus.html` | Giscus with theme-sync (§7) | If removed, falls back to Chirpy's stock Giscus (no theme sync) |
| `_layouts/post.html` | Post layout override (§6.3) | Yes, falls back to Chirpy default |
| `_plugins/posts-lastmod-hook.rb` | Git-based last_modified_at (§6.5) | Yes, posts lose "Updated" timestamp |
| `_plugins/sitemap-exclude-tag-archives.rb` | Keeps noindex tag pages out of the sitemap (§16) | Yes, but the sitemap lists noindex pages again |
| `_includes/head.html`, `_layouts/home.html`, `_data/locales/en.yml` | Full copies of theme files with SEO changes, each file's header comment lists them | No, and re-sync on every Chirpy upgrade |
| `assets/lib` (submodule), `assets/highlightjs/` | Self-hosted fonts and libraries | No, pages would lose fonts, icons and scripts |
| `_sass/addon/custom.scss` | Intentional placeholder (§6.4) | Yes, but read the comment first |
| `_tabs/*.md` | Sidebar + legal pages (§11) | Only `about.md`, `blogroll.md`, `contact.md`, and legal pages are custom; `archives.md`, `categories.md`, `tags.md` are Chirpy defaults you can delete to use theme-provided versions |
| `assets/img/avatar.jpg` | Sidebar avatar | No |
| `assets/img/og_image.png` | Site-wide OG fallback | No |
| `assets/img/posts/og-<slug>.png` | Per-post OG images | Per-post |
| `editor/index.html` | Deployed editor copy (§13) | Yes, but you lose `/editor/` |
| `.github/workflows/pages-deploy.yml` | Build + deploy (§12.1) | No |
| `.github/workflows/link-check.yml` | Weekly link check (§12.2) | Yes, but dead external links go unnoticed |
| `.github/workflows/indexnow.yml` | IndexNow ping (§12.4) | Yes |
| `.github/dependabot.yml` | Monthly update PRs (§12.5) | Yes, but actions and gems go stale |
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
