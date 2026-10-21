#!/usr/bin/env python3
"""Exercise Just command routing with fake tools; never build or activate systems."""

import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
JUST = shutil.which("just")
TOOLS = ("nixos-rebuild", "system-manager", "home-manager", "darwin-rebuild", "nix")


@unittest.skipUnless(JUST, "just is required")
class JustfileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="just routing ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.justfile = self.root / ".justfile"
        shutil.copyfile(ROOT / ".justfile", self.justfile)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        (self.bin / "sh").symlink_to(shutil.which("sh"))
        self.log = self.root / "calls.jsonl"
        self.cwd = self.root / "nested directory"
        self.cwd.mkdir()
        stub = (
            f"#!{sys.executable}\n"
            "import json, os, sys\n"
            "from pathlib import Path\n"
            "with open(os.environ['ROUTING_LOG'], 'a') as log:\n"
            "    log.write(json.dumps({'tool': Path(sys.argv[0]).name,\n"
            "        'args': sys.argv[1:], 'cwd': os.getcwd(),\n"
            "        'unfree': os.environ.get('NIXPKGS_ALLOW_UNFREE')}) + '\\n')\n"
            "sys.exit(int(os.environ.get('ROUTING_EXIT', '0')))\n"
        )
        for tool in TOOLS:
            executable = self.bin / tool
            executable.write_text(stub)
            executable.chmod(0o755)
        # Deliberately omit the real tool PATH: an unexpected invocation fails closed.
        self.env = {
            "PATH": str(self.bin),
            "HOME": str(self.root),
            "ROUTING_LOG": str(self.log),
        }

    def run_recipe(self, *args, success=True):
        self.log.unlink(missing_ok=True)
        result = subprocess.run(
            [JUST, "--justfile", str(self.justfile), *args],
            cwd=self.cwd,
            env=self.env,
            text=True,
            capture_output=True,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stderr)
        return (
            [json.loads(line) for line in self.log.read_text().splitlines()]
            if self.log.exists()
            else []
        )

    def assert_call(self, recipes, tool, args, unfree=None):
        self.assertEqual(
            self.run_recipe(*recipes),
            [{"tool": tool, "args": args, "cwd": str(self.root), "unfree": unfree}],
        )

    def test_shared_and_legacy_system_commands(self):
        cases = [
            ([], "nixos-rebuild", "home-nixos"),
            (["build"], "nixos-rebuild", "home-nixos"),
            (["build-zhb"], "nixos-rebuild", "zhb-nixos"),
            (["build-nixos", "other-nixos"], "nixos-rebuild", "other-nixos"),
            (["build-devbox"], "system-manager", "devbox"),
            (["build-vps"], "system-manager", "gkzhb-vps"),
            (["build-mido"], "system-manager", "mido"),
            (
                ["build-system-manager", "other-system"],
                "system-manager",
                "other-system",
            ),
            (["build-home", "zhanghaibin.zhb"], "home-manager", "zhanghaibin.zhb"),
            (["build-home-manager", "zhb"], "home-manager", "zhb"),
            (["build-darwin"], "darwin-rebuild", "gkzhb-MBP"),
            (["build-darwin", "other-mac"], "darwin-rebuild", "other-mac"),
        ]
        for recipes, tool, host in cases:
            with self.subTest(recipes=recipes):
                args = ["switch", "--flake", f".#{host}"]
                if tool == "system-manager":
                    args.append("--sudo")
                self.assert_call(recipes, tool, args)

    def test_package_wrappers(self):
        cases = [
            (["build-package", "knots"], ["build", ".#knots", "-L"], None),
            (
                ["build-alvr"],
                ["build", ".#alvr", "-L", "--cores", "4", "--max-jobs", "1"],
                None,
            ),
            (["build-aoci-code"], ["build", ".#aoci-code", "-L", "--impure"], "1"),
            (
                ["test-alvr-android"],
                [
                    "build",
                    ".#checks.x86_64-linux.alvr-android-workflow",
                    "-L",
                    "--no-link",
                ],
                None,
            ),
        ]
        for recipes, args, unfree in cases:
            with self.subTest(recipes=recipes):
                self.assert_call(recipes, "nix", args, unfree)

    def test_arguments_are_passed_literally(self):
        hostile = "name with spaces'\"; $(touch INJECTED); #"
        for recipe, tool in [
            ("build-nixos", "nixos-rebuild"),
            ("build-system-manager", "system-manager"),
            ("build-home-manager", "home-manager"),
            ("build-home", "home-manager"),
            ("build-darwin", "darwin-rebuild"),
        ]:
            with self.subTest(recipe=recipe):
                args = ["switch", "--flake", f".#{hostile}"]
                if tool == "system-manager":
                    args.append("--sudo")
                self.assert_call([recipe, hostile], tool, args)
        self.assert_call(
            ["build-package", hostile, "--out-link", hostile],
            "nix",
            ["build", f".#{hostile}", "-L", "--out-link", hostile],
        )
        self.assertFalse((self.root / "INJECTED").exists())

    def test_required_arguments(self):
        for recipe in (
            "build-nixos",
            "build-system-manager",
            "build-home-manager",
            "build-home",
            "build-package",
        ):
            with self.subTest(recipe=recipe):
                self.assertEqual(self.run_recipe(recipe, success=False), [])

    def test_failures_propagate(self):
        self.env["ROUTING_EXIT"] = "42"
        for recipe in (
            "build",
            "build-devbox",
            "build-darwin",
            "build-alvr",
            "build-aoci-code",
        ):
            with self.subTest(recipe=recipe):
                self.assertEqual(len(self.run_recipe(recipe, success=False)), 1)

    def test_unfree_permission_does_not_leak(self):
        calls = self.run_recipe("build-aoci-code", "build-package", "knots")
        self.assertEqual([call["unfree"] for call in calls], ["1", None])

    def test_android_build_remains_a_devshell_workflow(self):
        self.assert_call(
            ["build-alvr-android"],
            "nix",
            ["develop", ".#alvr-android", "--command", "alvr-android", "build"],
        )


if __name__ == "__main__":
    unittest.main()
