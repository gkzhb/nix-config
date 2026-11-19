#!/usr/bin/env python3
"""Exercise the Shepherdr renderer using an isolated HOME."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts/pi-sync-shepherdr.py"
PROFILES = ("general", "reviewer", "explorer")
HOSTS = {
    "magpie": ("magpie/auto/gpt-6.1-sol", "magpie/auto/ds-v4-flash"),
    "byte": ("byte/gpt-6.1-sol", "byte/ds-v4-flash"),
    "newapi": ("newapi/gpt-6.2-sol", "newapi/ds-v4-flash"),
}


class RenderTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="pi shepherdr ")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name).resolve()
        self.agent = self.root / "home/.pi/agent"
        self.agent.parent.parent.mkdir()
        self.source = self.root / "checkout/shepherdr"
        self.catalogs = self.root / "checkout/model-profiles"
        self.catalogs.mkdir(parents=True)
        for host, models in HOSTS.items():
            provider = host
            self.write_json(
                self.catalogs / f"{host}.json",
                {
                    "providers": {
                        provider: {
                            "models": [
                                {"id": model.split("/", 1)[1]} for model in models
                            ]
                        }
                    }
                },
            )
        for name in PROFILES:
            path = self.profile(self.source, name)
            path.parent.mkdir(parents=True)
            (path.parent / "prompt.md").write_text(f"Prompt for {name}")
            extra = {}
            if name == "reviewer":
                (path.parent / "prepare.mjs").write_text(
                    "export const prepare = () => 'review';"
                )
                extra = {
                    "blocking": True,
                    "share_context": False,
                    "accepts": ["base"],
                    "prepare": "prepare.mjs",
                }
            self.write_json(
                path,
                {
                    "model": "stale/model",
                    "description": name,
                    "thinking": "high",
                    "prompt": "prompt.md",
                    "pi_args": [],
                    **extra,
                },
            )
        self.output = self.agent / ".shepherdr-rendered"

    @staticmethod
    def profile(root, name):
        return root / "profiles" / name / "profile.json"

    @staticmethod
    def write_json(path, value):
        path.write_text(json.dumps(value), encoding="utf-8")

    def sync(
        self,
        *args,
        host="magpie",
        templates=None,
        catalog=None,
        models=None,
        success=True,
        agent_dir="",
    ):
        default, worker = HOSTS[host]
        result = subprocess.run(
            [
                sys.executable,
                SCRIPT,
                "--templates",
                templates or self.source,
                "--catalog",
                catalog or self.catalogs / f"{host}.json",
                "--output",
                self.output,
                "--models",
                json.dumps(
                    models
                    or {
                        "general": default,
                        "reviewer": default,
                        "explorer": worker,
                    }
                ),
                *args,
            ],
            env={**os.environ, "PI_CODING_AGENT_DIR": str(agent_dir)},
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result.stderr

    def test_three_hosts_render_complete_profiles(self):
        # Prefer the actual independent checkout when available. The isolated
        # fixture also lets this test run from a nix-config-only checkout.
        checkout = REPO / "dotfiles/.pi/agent"
        templates = checkout / "shepherdr"
        catalogs = checkout / "model-profiles"
        if not templates.is_dir() or not catalogs.is_dir():
            templates, catalogs = self.source, self.catalogs
        before = {
            path: path.read_bytes()
            for path in templates.glob("profiles/*/*")
            if path.is_file()
        }
        for host, (default, worker) in HOSTS.items():
            with self.subTest(host=host):
                self.sync(
                    host=host, templates=templates, catalog=catalogs / f"{host}.json"
                )
                for name in PROFILES:
                    target = self.profile(self.output, name)
                    self.assertTrue(target.is_file())
                    self.assertFalse(target.is_symlink())
                    original = json.loads(self.profile(templates, name).read_text())
                    self.assertEqual(
                        json.loads(target.read_text()),
                        {
                            **original,
                            "model": worker if name == "explorer" else default,
                        },
                    )
                    for field in ("prompt", "prepare"):
                        if field in original:
                            asset = target.parent / original[field]
                            self.assertEqual(
                                asset.resolve(),
                                (
                                    templates / "profiles" / name / original[field]
                                ).resolve(),
                            )
        self.assertEqual({path: path.read_bytes() for path in before}, before)
        self.assertTrue((self.output / ".profiles-initialized").is_file())

    def test_preflight_and_old_link_migration_do_not_touch_checkout(self):
        self.agent.mkdir(parents=True)
        old_generation = self.root / "old-home-manager-files/.pi/agent"
        old_generation.mkdir(parents=True)
        (old_generation / "shepherdr").symlink_to(self.source, target_is_directory=True)
        entry = self.agent / "shepherdr"
        entry.symlink_to(old_generation / "shepherdr", target_is_directory=True)
        self.sync("--check")
        self.assertFalse(self.output.exists())
        self.sync()
        self.assertEqual(entry.resolve(), self.source)
        self.assertEqual(
            json.loads(self.profile(entry, "general").read_text())["model"],
            "stale/model",
        )
        # Simulate linkGeneration replacing the same managed path.
        entry.unlink()
        entry.symlink_to(self.output, target_is_directory=True)
        self.assertEqual(
            json.loads(self.profile(entry, "general").read_text())["model"],
            HOSTS["magpie"][0],
        )

    def test_repeat_preserves_runtime_state_and_reloads_templates(self):
        self.sync()
        path = self.profile(self.output, "reviewer")
        previous_mtime = path.stat().st_mtime_ns
        state = self.output / "context"
        state.mkdir()
        (state / "receipt").write_text("local")
        self.sync()
        self.assertEqual(path.stat().st_mtime_ns, previous_mtime)
        template = self.profile(self.source, "reviewer")
        self.write_json(
            template, {**json.loads(template.read_text()), "thinking": "xhigh"}
        )
        self.sync()
        self.assertEqual(json.loads(path.read_text())["thinking"], "xhigh")
        self.assertEqual((state / "receipt").read_text(), "local")

    def test_bad_model_or_template_never_updates_existing_outputs(self):
        self.sync()
        saved = {
            self.profile(self.output, name): self.profile(
                self.output, name
            ).read_bytes()
            for name in PROFILES
        }
        for check in ((), ("--check",)):
            self.assertIn(
                "not a chat model",
                self.sync(
                    *check,
                    success=False,
                    models={
                        "general": HOSTS["magpie"][0],
                        "reviewer": HOSTS["magpie"][0],
                        "explorer": "magpie/wrong",
                    },
                ),
            )
        template = self.profile(self.source, "explorer")
        data = json.loads(template.read_text())
        for field in (
            {"pi_args": ["--model", "other/model"]},
            {"prompt": "../other.md"},
        ):
            self.write_json(template, {**data, **field})
            self.sync(host="byte", success=False)
        self.assertEqual({path: path.read_bytes() for path in saved}, saved)

    def test_refuses_to_write_through_output_link_or_mismatched_agent_dir(self):
        self.assertIn(
            "PI_CODING_AGENT_DIR", self.sync(agent_dir=self.source, success=False)
        )
        self.agent.mkdir(parents=True)
        self.output.symlink_to(self.source, target_is_directory=True)
        self.assertIn("refusing to render", self.sync(success=False))
        self.output.unlink()
        self.sync()
        target = self.profile(self.output, "explorer")
        target.unlink()
        target.symlink_to(self.profile(self.source, "explorer"))
        self.assertIn("must be a regular file", self.sync(success=False))
        self.assertTrue(target.is_symlink())

    def test_rejects_non_symlink_asset_without_replacing_it(self):
        self.sync()
        prompt = self.profile(self.output, "general").with_name("prompt.md")
        prompt.unlink()
        shutil.copyfile(
            self.profile(self.source, "general").with_name("prompt.md"), prompt
        )
        self.assertIn("non-symlink asset", self.sync(success=False))
        self.assertFalse(prompt.is_symlink())


if __name__ == "__main__":
    unittest.main()
