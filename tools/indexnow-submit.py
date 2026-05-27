#!/usr/bin/env python3
"""
IndexNow submission script for EUC Insights blog.

Reads changed _posts/*.md files between two git SHAs, converts them to
permalink URLs, and POSTs them to api.indexnow.org so Bing, Yandex, and
DuckDuckGo learn about the new or updated content immediately.

Designed to run from a GitHub Actions workflow (.github/workflows/indexnow.yml)
on every successful Pages deploy. Can also be run manually to seed the
index with all existing posts (--all).

Usage from CI:
    BEFORE_SHA=<previous>  AFTER_SHA=<current>  python3 tools/indexnow-submit.py

Usage manually (seed all posts):
    python3 tools/indexnow-submit.py --all

Env vars:
    BEFORE_SHA   Git SHA of the previous commit (defaults to HEAD~1)
    AFTER_SHA    Git SHA of the current commit (defaults to HEAD)
    SITE_URL     Base URL of the site (default: https://robertmagasi.com)
    INDEXNOW_KEY Key string (default: d3d07fc2675393a4c9805edc4eaccf2c)

Exit codes:
    0   Submission accepted, or no URLs to submit
    1   Submission rejected by IndexNow
    2   Local error (git not available, key file missing, etc.)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

SITE_URL = os.environ.get("SITE_URL", "https://robertmagasi.com").rstrip("/")
HOST = SITE_URL.replace("https://", "").replace("http://", "")
KEY = os.environ.get("INDEXNOW_KEY", "d3d07fc2675393a4c9805edc4eaccf2c")
KEY_LOCATION = f"{SITE_URL}/{KEY}.txt"
ENDPOINT = "https://api.indexnow.org/IndexNow"

POST_FILENAME_RE = re.compile(r"^_posts/(\d{4}-\d{2}-\d{2})-(?P<slug>.+)\.md$")


def run_git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        sys.stderr.write(f"git {' '.join(args)} failed: {result.stderr}\n")
        sys.exit(2)
    return result.stdout.strip()


def changed_post_files(before: str, after: str) -> list[str]:
    """Return _posts/*.md files added or modified between two SHAs."""
    if not before or set(before) == {"0"}:
        # First push or force push, fall back to the parent of after.
        before = run_git("rev-parse", f"{after}^") or after
    diff = run_git(
        "diff",
        "--name-only",
        "--diff-filter=AM",
        before,
        after,
        "--",
        "_posts/*.md",
    )
    return [line for line in diff.splitlines() if line.strip()]


def all_post_files() -> list[str]:
    repo_root = Path(run_git("rev-parse", "--show-toplevel"))
    posts_dir = repo_root / "_posts"
    return [
        f"_posts/{p.name}"
        for p in sorted(posts_dir.glob("*.md"))
        if POST_FILENAME_RE.match(f"_posts/{p.name}")
    ]


def file_to_url(post_path: str) -> str | None:
    match = POST_FILENAME_RE.match(post_path)
    if not match:
        return None
    return f"{SITE_URL}/posts/{match.group('slug')}/"


def submit(urls: list[str]) -> int:
    payload = {
        "host": HOST,
        "key": KEY,
        "keyLocation": KEY_LOCATION,
        "urlList": urls,
    }
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        ENDPOINT,
        data=body,
        headers={"Content-Type": "application/json; charset=utf-8"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            status = resp.status
            text = resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        status = e.code
        text = e.read().decode("utf-8", errors="replace")
    except urllib.error.URLError as e:
        sys.stderr.write(f"Network error: {e}\n")
        return 2

    print(f"IndexNow responded {status}: {text or '(empty body)'}")
    # 200 OK, 202 Accepted are both success per the IndexNow spec.
    return 0 if status in (200, 202) else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--all",
        action="store_true",
        help="Submit every post in _posts/ instead of diffing two SHAs.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the URLs that would be submitted and exit.",
    )
    args = parser.parse_args()

    if args.all:
        post_files = all_post_files()
    else:
        before = os.environ.get("BEFORE_SHA", "")
        after = os.environ.get("AFTER_SHA", "HEAD")
        post_files = changed_post_files(before, after)

    urls: list[str] = []
    for f in post_files:
        url = file_to_url(f)
        if url:
            urls.append(url)

    # Always include the homepage and sitemap when something has changed,
    # they regenerate on any post add or edit.
    if urls:
        urls.append(f"{SITE_URL}/")
        urls.append(f"{SITE_URL}/sitemap.xml")

    # Deduplicate while preserving order.
    seen = set()
    deduped = []
    for u in urls:
        if u not in seen:
            seen.add(u)
            deduped.append(u)
    urls = deduped

    if not urls:
        print("No post changes detected, nothing to submit.")
        return 0

    print(f"Submitting {len(urls)} URL(s) to IndexNow:")
    for u in urls:
        print(f"  {u}")

    if args.dry_run:
        return 0

    return submit(urls)


if __name__ == "__main__":
    sys.exit(main())
