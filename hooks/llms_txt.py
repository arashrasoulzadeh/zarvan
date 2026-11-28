"""Publish Markdown discovery resources using MkDocs' actual navigation URLs."""

import hashlib
import json
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


def _write_text(site, relative, text):
    path = site / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _operation_groups(markdown):
    # The generated operations reference uses one lower-case H2 per group.
    # Keep the header/permission contract with every group; do not split
    # on H3 operation names or fenced snippets.
    sections = re.split(r"(?m)^## ([a-z][a-z0-9_]*)\s*$", markdown)
    intro = sections[0].strip()
    for i in range(1, len(sections), 2):
        name, body = sections[i:i + 2]
        yield name, f"{intro}\n\n## {name}\n{body.rstrip()}\n"


def on_post_build(config, **kwargs):
    base = (config.get("site_url") or "").rstrip("/") + "/"
    site = Path(config["site_dir"])
    manifest = {"formatVersion": 1, "pages": [], "operationGroups": []}
    lines = ["# ZARVAN", "", f"> {SUMMARY}", "",
             "Start with the Agent hub for integration contracts. "
             "Use the live operation registry for exact tool schemas. Links below serve raw Markdown; "
             "each page identifies its canonical HTML URL and original source path. "
             "Relative links refer to the original source tree.", "",
             f"- [Full documentation Markdown]({urljoin(base, 'llms-full.txt')})",
             f"- [Machine-readable documentation manifest]({urljoin(base, 'agent-docs/manifest.json')})",
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
        raw_path = f"agent-docs/pages/{rel}"
        raw_url = urljoin(base, raw_path)
        raw = f"Source: {rel}\nURL: {canonical}\n\n{_body(markdown).rstrip()}\n"
        digest = _write_text(site, raw_path, raw)
        manifest["pages"].append({
            "source": rel, "title": title, "description": desc,
            "url": canonical, "markdownUrl": raw_url, "sha256": digest,
            "language": "fa" if rel.startswith("fa/") else "en",
        })
        lines.append(f"- [{title}]({raw_url})" + (f": {desc}" if desc else ""))
        if rel == "reference/operations.md":
            for group, body in _operation_groups(markdown):
                group_path = f"agent-docs/operations/{group}.md"
                group_url = urljoin(base, group_path)
                digest = _write_text(site, group_path, body)
                manifest["operationGroups"].append({
                    "name": group, "markdownUrl": group_url,
                    "url": f"{canonical}#{group}", "sha256": digest,
                })
        full.extend(["---", "", f"Source: {rel}", f"URL: {canonical}", "",
                     _body(markdown).rstrip(), ""])
    lines.extend(["", "## Operation groups", ""])
    for group in manifest["operationGroups"]:
        lines.append(f"- [{group['name']}]({group['markdownUrl']})")
    _write_text(site, "agent-docs/manifest.json",
                json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    (site / "llms.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (site / "llms-full.txt").write_text("\n".join(full) + "\n", encoding="utf-8")
