"""Publish Markdown discovery resources using MkDocs' actual navigation URLs."""

import re
from pathlib import Path
from urllib.parse import urljoin

SUMMARY = (
    "An agent-native, simulation-first 2D game engine built with Dart. "
    "Content and world state are JSON; the operation registry exposes "
    "validated project and simulation operations."
)

_pages = []


def _body(markdown):
    return re.sub(r"^---\n.*?\n---\s*", "", markdown, count=1, flags=re.S)


def _first_sentence(markdown):
    front = re.match(r"^---\n(.*?)\n---", markdown, flags=re.S)
    if front:
        desc = re.search(r"^description:\s*(.+)$", front[1], flags=re.M)
        if desc:
            return desc[1].strip().strip('"')[:200]
    for block in re.split(r"\n\s*\n", _body(markdown)):
        text = block.strip()
        if not text or text.startswith(("#", "```", "|", "<", "!!!", "=", "-", ":")):
            continue
        text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)
        text = re.sub(r"[*`>]", "", text).replace("\n", " ")
        return re.split(r"(?<=[.!?])\s", text, maxsplit=1)[0][:200]
    return ""


def on_nav(nav, config, files, **kwargs):
    # Use MkDocs' page URLs rather than guessing directory/index conventions.
    # Reset on every rebuild (including mkdocs serve).
    _pages.clear()
    for page in nav.pages:
        rel = page.file.src_uri
        if rel == "README.md":  # standalone landing page, not technical docs
            continue
        path = page.file.abs_src_path
        if not path or not rel.endswith(".md"):
            continue
        _pages.append((rel, page.url, page.title, Path(path)))
    return nav


def on_post_build(config, **kwargs):
    base = (config.get("site_url") or "").rstrip("/") + "/"
    lines = ["# ZARVAN", "", f"> {SUMMARY}", "",
             "Start with the Agent hub for integration contracts. "
             "Use the live operation registry for exact tool schemas.", "",
             f"- [Full documentation Markdown]({urljoin(base, 'llms-full.txt')})",
             "", "## Pages", ""]
    full = ["# ZARVAN technical documentation", "", f"> {SUMMARY}", "",
            "Each page is identified by its canonical URL and source path. "
            "Relative links in the original Markdown are relative to that source page.", ""]
    ordered = sorted(_pages, key=lambda page: (
        {"agents.md": 0, "guides/for-ai-agents.md": 1,
         "getting-started.md": 2, "reference/operations.md": 3,
         "reference/components.md": 4}.get(page[0], 5),
        page[0],
    ))
    for rel, url, title, path in ordered:
        markdown = path.read_text(encoding="utf-8")
        heading = re.search(r"^#\s+(.+)$", markdown, flags=re.M)
        title = title or (heading[1].strip() if heading else rel)
        canonical = urljoin(base, url)
        desc = _first_sentence(markdown)
        lines.append(f"- [{title}]({canonical})" + (f": {desc}" if desc else ""))
        full.extend(["---", "", f"Source: {rel}", f"URL: {canonical}", "",
                     _body(markdown).rstrip(), ""])
    site = Path(config["site_dir"])
    (site / "llms.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (site / "llms-full.txt").write_text("\n".join(full) + "\n", encoding="utf-8")
