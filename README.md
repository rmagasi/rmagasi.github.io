# EUC Insights — robertmagasi.com

Personal technical blog by **Robert Magasi** — Senior VDI & EUC Consultant.
Real-world Citrix, AVD, and EUC knowledge from 15 years in IT.

## Stack

| Layer | Choice |
|-------|--------|
| Hosting | GitHub Pages (deployed via GitHub Actions) |
| Generator | Jekyll 4.x |
| Theme | [Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) v7.4.1 (gem-based) |
| Comments | [Giscus](https://giscus.app) (GitHub Discussions-backed) |
| Analytics | [GoatCounter](https://www.goatcounter.com/) (cookieless) |
| Editor | Custom single-file HTML editor (separate repo) |

## Publishing workflow

1. **Draft** a post via the custom Cowork editor — produces a `.md` file under `_drafts/` or `_posts/` using the front matter template.
2. **Generate the OG image** with `scripts/generate_og.py` (from the `euc-insights-blog` skill) and save to `assets/img/posts/og-<slug>.png`.
3. **Publish** via the editor's Publish button. The editor pushes `.md` files directly to the repo via the GitHub Contents API.
4. **Commit image assets manually** — the editor only handles markdown. Run:
   ```bash
   git add assets/img/posts/og-<slug>.png
   git commit -m "add post: <title>"
   git push
   ```
5. **GitHub Actions** (`.github/workflows/pages-deploy.yml`) builds with Jekyll, runs htmlproofer, and deploys to Pages.

## Local development

```bash
bundle install
bundle exec jekyll serve
```

Site will be available at http://localhost:4000.

## Repo layout

```
_posts/        Published posts (YYYY-MM-DD-slug.md)
_drafts/       Draft posts + post template
_tabs/         Sidebar pages (About, Blogroll, Contact, legal pages)
_includes/
  metadata-hook.html   All custom JS/CSS
  comments/giscus.html Giscus widget + theme sync
_layouts/      Overrides for Chirpy's default layouts
_data/         Author, contact, share config
assets/img/    Avatar, OG images, favicons, post screenshots
assets/scripts/ Downloadable scripts referenced in posts
```

## Key conventions

- **Author** is always `robert` (see `_data/authors.yml`)
- **Categories** are title-cased; **tags** are lowercase-hyphenated
- **OG images** are 1200×630 (generated at 2× for retina crispness)
- **Custom CSS/JS** goes in `_includes/metadata-hook.html` — NOT `_sass/addon/custom.scss` (ignored in gem-based Chirpy)
- **Inline scripts** must use `/* */` block comments, never `//` — `compress_html` breaks `//`

## License

Post content © Robert Magasi. Code snippets unless otherwise noted are MIT-licensed.
Chirpy theme is MIT-licensed — see [cotes2020/jekyll-theme-chirpy](https://github.com/cotes2020/jekyll-theme-chirpy).
