#!/usr/bin/env python3
"""Isolated behavior checks: fake Nix tools, never real GC or profile pruning."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'nix-darwin-gc.sh'

class CleanupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.log = self.root / 'calls'
        self.env = dict(os.environ, CALL_LOG=str(self.log), PRUNE_RC='0', GC_RC='0')
        self.store = self.root / 'store'
        self.store.mkdir()
        self.profile = self.root / 'system'
        self.profile.symlink_to(self.store)
        for name, rc in [('nix-env','PRUNE_RC'), ('nix-store','GC_RC')]:
            p = self.bin / name
            p.write_text(f'#!/bin/bash\nprintf "%s\\n" "{name} $*" >> "$CALL_LOG"\nexit "${{{rc}}}"\n')
            p.chmod(0o755)

    def tearDown(self):
        self.temp.cleanup()

    def run_script(self, *args):
        return subprocess.run(['/bin/bash', str(SCRIPT), *(args or [str(self.bin), str(self.profile)])], env=self.env, capture_output=True, text=True)

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_preserve_five_history_plus_current_and_gc_in_order(self):
        r = self.run_script()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.calls(), [f'nix-env --profile {self.profile} --delete-generations +6', 'nix-store --gc'])

    def test_prune_failure_prevents_gc(self):
        self.env['PRUNE_RC'] = '17'
        self.assertEqual(self.run_script().returncode, 17)
        self.assertEqual(len(self.calls()), 1)

    def test_gc_failure_propagates(self):
        self.env['GC_RC'] = '19'
        r = self.run_script()
        self.assertEqual(r.returncode, 19)
        self.assertNotIn('completed at', r.stdout)

    def test_missing_profile_is_rejected(self):
        self.profile.unlink()
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_broken_profile_is_rejected(self):
        self.store.rmdir()
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_relative_path_is_rejected(self):
        self.assertEqual(self.run_script('relative/bin', str(self.profile)).returncode, 2)
        self.assertEqual(self.calls(), [])

    def test_paths_with_spaces_remain_single_arguments(self):
        profile = self.root / 'system profile'
        profile.symlink_to(self.store)
        self.assertEqual(self.run_script(str(self.bin), str(profile)).returncode, 0)
        self.assertEqual(self.calls()[0], f'nix-env --profile {profile} --delete-generations +6')

if __name__ == '__main__':
    unittest.main()
