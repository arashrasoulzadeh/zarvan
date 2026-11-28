"""Tests for the documentation discovery index, without running MkDocs."""

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
            ]:
                path = root / rel
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(
                    f"# {title}\n\nUseful content for {title}.\n",
                    encoding="utf-8",
                )
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
            self.assertIn("https://example.test/zarvan/tutorials/", index)
            self.assertIn("https://example.test/zarvan/fa/", index)
            self.assertIn("Useful content for Agent hub.", full)
            self.assertNotIn("Landing", index)
            self.assertNotIn("Landing", full)
            self.assertNotIn("//tutorials", index)


if __name__ == "__main__":
    unittest.main()
