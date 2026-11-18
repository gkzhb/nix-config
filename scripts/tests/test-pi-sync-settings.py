#!/usr/bin/env python3
"""Exercise Pi settings sync without touching HOME or a real checkout."""

import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "pi-sync-settings.py"


class SyncTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="pi settings ")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name).resolve()
        self.checkout = self.root / "checkout"
        self.checkout.mkdir()
        self.shared = self.checkout / "settings.shared.json"
        self.shared.write_text(
            json.dumps(
                {
                    "theme": "dark",
                    "packages": ["shared"],
                    "tidy": {"padding": 4},
                }
            )
        )
        self.settings = self.root / ".pi" / "agent" / "settings.json"
        self.settings.parent.mkdir(parents=True)
        self.overrides = {
            "defaultProvider": "local",
            "defaultModel": "provider/model",
            "enabledModels": [],
        }

    def sync(self, *args, success=True, agent_dir=None):
        env = {**os.environ, "PI_CODING_AGENT_DIR": str(agent_dir or "")}
        result = subprocess.run(
            [
                sys.executable,
                SCRIPT,
                "--settings",
                self.settings,
                "--shared",
                self.shared,
                "--overrides",
                json.dumps(self.overrides),
                *args,
            ],
            env=env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def test_merge_keeps_local_state_and_replaces_arrays(self):
        self.settings.write_text(
            json.dumps(
                {
                    "defaultProvider": "other",
                    "defaultModel": "old",
                    "enabledModels": ["other/**"],
                    "packages": ["old"],
                    "tidy": {"padding": 9, "keep": True},
                    "lastChangelogVersion": "1.4.0",
                }
            )
        )
        original_shared = self.shared.read_bytes()
        self.sync()
        self.assertEqual(
            json.loads(self.settings.read_text()),
            {
                **self.overrides,
                "theme": "dark",
                "packages": ["shared"],
                "tidy": {"padding": 4, "keep": True},
                "lastChangelogVersion": "1.4.0",
            },
        )
        self.assertEqual(stat.S_IMODE(self.settings.stat().st_mode), 0o600)
        self.assertEqual(self.shared.read_bytes(), original_shared)
        previous = self.settings.read_bytes()
        self.sync()
        self.assertEqual(self.settings.read_bytes(), previous)

    def test_fresh_settings(self):
        self.sync()
        self.assertEqual(
            json.loads(self.settings.read_text())["defaultModel"], "provider/model"
        )
        self.assertFalse(self.settings.is_symlink())

    def test_migrate_from_backup_once(self):
        backup = self.root / "old-settings.json"
        backup.write_text('{"localState":1}')
        self.sync("--from", backup)
        self.assertEqual(json.loads(self.settings.read_text())["localState"], 1)
        previous = self.settings.read_bytes()
        self.assertIn(
            "only for initial migration",
            self.sync("--from", backup, success=False).stderr,
        )
        self.assertEqual(self.settings.read_bytes(), previous)
        self.assertEqual(backup.read_text(), '{"localState":1}')

    def test_home_manager_upgrade_checks_then_seeds_after_unlink(self):
        old_generation = self.root / "old-generation"
        old_generation.mkdir()
        old_settings = old_generation / "settings.json"
        original = '{"theme":"light","localState":1}'
        old_settings.write_text(original)
        self.settings.symlink_to(old_settings)

        self.sync("--check", "--from", old_settings)
        self.assertEqual(self.settings.readlink(), old_settings)
        self.assertEqual(old_settings.read_text(), original)
        self.sync("--from", old_settings, success=False)
        self.sync("--check", "--from", self.shared, success=False)
        self.assertEqual(self.settings.readlink(), old_settings)

        self.settings.unlink()  # Simulate Home Manager's linkGeneration.
        self.sync("--from", old_settings)
        self.assertEqual(json.loads(self.settings.read_text())["localState"], 1)
        self.assertEqual(json.loads(self.settings.read_text())["theme"], "dark")
        self.assertEqual(old_settings.read_text(), original)
        self.assertFalse(self.settings.is_symlink())

    def test_check_only_does_not_create_or_update_settings(self):
        self.settings.parent.rmdir()
        self.sync("--check")
        self.assertFalse(self.settings.parent.exists())
        self.settings.parent.mkdir()
        self.settings.write_text('{"theme":"light"}')
        self.sync("--check")
        self.assertEqual(self.settings.read_text(), '{"theme":"light"}')

    def test_existing_and_dangling_symlinks_are_not_changed(self):
        for target in (self.shared, self.checkout / "missing.json"):
            with self.subTest(target=target):
                previous = self.shared.read_bytes()
                self.settings.symlink_to(target)
                self.assertIn("is a symlink", self.sync(success=False).stderr)
                self.sync("--check", success=False)
                self.assertEqual(self.settings.readlink(), target)
                self.assertEqual(self.shared.read_bytes(), previous)
                self.settings.unlink()

    def test_symlinked_parent_is_not_written(self):
        agent = self.settings.parent
        agent.rmdir()
        agent.symlink_to(self.checkout, target_is_directory=True)
        self.assertIn("symlinked", self.sync(success=False).stderr)
        self.assertFalse((self.checkout / self.settings.name).exists())

    def test_invalid_input_does_not_overwrite_settings(self):
        self.settings.write_text('{"localState":true}')
        previous = self.settings.read_bytes()
        for invalid in ("{", "[]", '{"invalid":NaN}'):
            with self.subTest(invalid=invalid):
                self.shared.write_text(invalid)
                self.sync(success=False)
                self.sync("--check", success=False)
                self.assertEqual(self.settings.read_bytes(), previous)
        self.shared.write_text("{}")
        self.settings.write_text("[]")
        self.sync(success=False)
        self.assertEqual(self.settings.read_text(), "[]")

    def test_reject_nondefault_agent_dir(self):
        self.assertIn(
            "PI_CODING_AGENT_DIR",
            self.sync(success=False, agent_dir=self.checkout).stderr,
        )
        self.assertFalse(self.settings.exists())
        self.sync(agent_dir=self.settings.parent)


if __name__ == "__main__":
    unittest.main()
