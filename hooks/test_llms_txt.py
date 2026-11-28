"""Tests for the documentation discovery index, without running MkDocs."""

import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

import llms_txt


class DiscoveryTests(unittest.TestCase):
    def test_nav_urls_and_full_text(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            output = root / "site"
            output.mkdir()
            pages = []
            for rel, url, title in [
                ("README.md", "", "Landing"),
                ("tutorials/README.md", "tutorials/", "Tutorials"),
                ("agents.md", "agents/", "Agent hub"),
                ("fa/index.md", "fa/", "فارسی"),
                ("reference/operations.md", "reference/operations/", "Operations"),
            ]:
                path = root / rel
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(
                    f"# {title}\n\nUseful content for {title}.\n",
                    encoding="utf-8",
                )
                if rel == "reference/operations.md":
                    path.write_text("# Operations\n\nPermission contract.\n\n"
                                    "## world\n\n### `world.build`\n\nBuild.\n\n"
                                    "## schema\n\n### `schema.component`\n\nDescribe.\n",
                                    encoding="utf-8")
                pages.append(SimpleNamespace(
                    title=title, url=url,
                    file=SimpleNamespace(src_uri=rel, abs_src_path=str(path)),
                ))
            nav = SimpleNamespace(pages=pages)
            config = {"site_url": "https://example.test/zarvan/", "site_dir": str(output)}
            self.assertIs(llms_txt.on_nav(nav, config, None), nav)
            llms_txt.on_post_build(config)
            index = (output / "llms.txt").read_text(encoding="utf-8")
            full = (output / "llms-full.txt").read_text(encoding="utf-8")
            manifest = json.loads((output / "agent-docs/manifest.json").read_text(
                encoding="utf-8"))
            self.assertEqual(manifest["formatVersion"], 1)
            self.assertEqual(len(manifest["pages"]), 4)
            self.assertEqual([g["name"] for g in manifest["operationGroups"]],
                             ["world", "schema"])
            self.assertIn("https://example.test/zarvan/agent-docs/pages/tutorials/README.md", index)
            self.assertIn("https://example.test/zarvan/agent-docs/pages/fa/index.md", index)
            tutorials = next(p for p in manifest["pages"] if p["source"] == "tutorials/README.md")
            self.assertEqual(tutorials["url"], "https://example.test/zarvan/tutorials/")
            raw = (output / "agent-docs/pages/tutorials/README.md").read_bytes()
            self.assertEqual(tutorials["sha256"], hashlib.sha256(raw).hexdigest())
            world = (output / "agent-docs/operations/world.md").read_text(encoding="utf-8")
            self.assertIn("Permission contract.", world)
            self.assertIn("world.build", world)
            self.assertNotIn("schema.component", world)
            self.assertIn("https://example.test/zarvan/agent-docs/operations/world.md", index)
            self.assertFalse((output / "agent-docs/pages/README.md").exists())
            self.assertIn("Useful content for Agent hub.", full)
            self.assertNotIn("Landing", index)
            self.assertNotIn("Landing", full)
            self.assertNotIn("//tutorials", index)


if __name__ == "__main__":
    unittest.main()
