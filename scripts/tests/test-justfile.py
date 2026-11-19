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
TOOLS = (
    "nixos-rebuild", "system-manager", "home-manager", "darwin-rebuild",
    "nix", "git", "systemctl", "journalctl",
)


@unittest.skipUnless(JUST, "just is required")
class JustfileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="just routing ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.justfile = self.root / ".justfile"
        shutil.copyfile(ROOT / ".justfile", self.justfile)
        (self.root / "scripts").mkdir()
        shutil.copyfile(
            ROOT / "scripts/check-home-manager.sh",
            self.root / "scripts/check-home-manager.sh",
        )
        self.bin = self.root / "bin"
        self.bin.mkdir()
        (self.bin / "sh").symlink_to(shutil.which("sh"))
        # npm's rust-just launcher needs Node even when the tool PATH is isolated.
        node = shutil.which("node")
        if node:
            (self.bin / "node").symlink_to(node)
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
            "tool = Path(sys.argv[0]).name\n"
            "if tool == 'systemctl' and 'status' in sys.argv:\n"
            "    print('fake Home Manager service status')\n"
            "if tool == 'journalctl':\n"
            "    print('fake Home Manager activation log')\n"
            "key = 'ROUTING_EXIT_' + tool.upper().replace('-', '_')\n"
            "sys.exit(int(os.environ.get(key, os.environ.get('ROUTING_EXIT', '0'))))\n"
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
        self.last_result = result
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
            (["build-system-manager", "devbox"], "system-manager", "devbox"),
            (["build-vps"], "system-manager", "gkzhb-vps"),
            (["build-mido"], "system-manager", "mido"),
            (
                ["build-system-manager", "other-system"],
                "system-manager",
                "other-system",
            ),
            (["build-home", "other.user"], "home-manager", "other.user"),
            (["build-home-manager", "zhb"], "home-manager", "zhb"),
            (["build-darwin"], "darwin-rebuild", "gkzhb-MBP"),
            (["build-darwin", "other-mac"], "darwin-rebuild", "other-mac"),
        ]
        for recipes, tool, host in cases:
            with self.subTest(recipes=recipes):
                args = ["switch", "--flake", f".#{host}"]
                if tool == "nixos-rebuild":
                    args.append("--accept-flake-config")
                elif tool == "system-manager":
                    args.extend(
                        ["--sudo", "--nix-option", "accept-flake-config", "true"]
                    )
                else:
                    args.extend(["--option", "accept-flake-config", "true"])
                self.assert_call(recipes, tool, args)

    def test_devbox_checks_home_manager_after_switch(self):
        for recipes in (["build-devbox"], ["build-system-manager", "devbox", "zhanghaibin.zhb"]):
            with self.subTest(recipes=recipes):
                calls = self.run_recipe(*recipes)
                self.assertEqual([call["tool"] for call in calls], ["system-manager", "systemctl"])
                self.assertEqual(calls[0]["args"], [
                    "switch", "--flake", ".#devbox", "--sudo",
                    "--nix-option", "accept-flake-config", "true",
                ])
                self.assertEqual(calls[1]["args"], [
                    "is-active", "--quiet", "home-manager-zhanghaibin.zhb.service",
                ])
                self.assertTrue(all(call["cwd"] == str(self.root) for call in calls))

    def test_home_manager_failure_prints_diagnostics_and_fails(self):
        self.env["ROUTING_EXIT_SYSTEMCTL"] = "3"
        recipes_to_check = [
            ["build-devbox"], ["build-system-manager", "devbox", "zhanghaibin.zhb"],
            ["check-home-manager", "zhanghaibin.zhb"],
        ]
        for recipes in recipes_to_check:
            for journal_exit in ("0", "4"):
                with self.subTest(recipes=recipes, journal_exit=journal_exit):
                    self.env["ROUTING_EXIT_JOURNALCTL"] = journal_exit
                    calls = self.run_recipe(*recipes, success=False)
                    checks = calls[1:] if recipes[0] != "check-home-manager" else calls
                    self.assertEqual([call["tool"] for call in checks], [
                        "systemctl", "systemctl", "journalctl",
                    ])
                    self.assertEqual(checks[1]["args"], [
                        "--no-pager", "--full", "status",
                        "home-manager-zhanghaibin.zhb.service",
                    ])
                    self.assertEqual(checks[2]["args"], [
                        "--boot", "--unit", "home-manager-zhanghaibin.zhb.service",
                        "--no-pager", "--lines", "80",
                    ])
                    self.assertIn("fake Home Manager service status", self.last_result.stderr)
                    self.assertIn("fake Home Manager activation log", self.last_result.stderr)

    def test_home_manager_checker_is_reusable_for_multiple_users(self):
        for recipes in (
            ["check-home-manager", "alice", "bob.user"],
            ["build-system-manager", "other-system", "alice", "bob.user"],
            ["build-system-manager", "devbox", "alice", "bob.user"],
        ):
            with self.subTest(recipes=recipes):
                calls = self.run_recipe(*recipes)
                checks = calls[1:] if recipes[0] == "build-system-manager" else calls
                self.assertEqual([call["args"] for call in checks], [
                    ["is-active", "--quiet", "home-manager-alice.service"],
                    ["is-active", "--quiet", "home-manager-bob.user.service"],
                ])

    def test_home_manager_checker_continues_after_failure(self):
        self.env["ROUTING_EXIT_SYSTEMCTL"] = "4"
        calls = self.run_recipe("check-home-manager", "alice", "bob", success=False)
        self.assertEqual([call["tool"] for call in calls], [
            "systemctl", "systemctl", "journalctl",
            "systemctl", "systemctl", "journalctl",
        ])
        self.assertIn("home-manager-bob.service", self.last_result.stderr)

    def test_switch_failure_skips_home_manager_check(self):
        self.env["ROUTING_EXIT_SYSTEM_MANAGER"] = "42"
        for recipes in (["build-devbox"], ["build-system-manager", "devbox", "zhanghaibin.zhb"]):
            with self.subTest(recipes=recipes):
                calls = self.run_recipe(*recipes, success=False)
                self.assertEqual([call["tool"] for call in calls], ["system-manager"])

    def test_home_manager_checker_requires_users(self):
        self.assertEqual(self.run_recipe("check-home-manager", success=False), [])
        result = subprocess.run(
            [str(self.bin / "sh"), str(self.root / "scripts/check-home-manager.sh")],
            env=self.env, text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("Usage:", result.stderr)
        self.assertEqual(self.run_recipe("check-home-manager", "", success=False), [])

    def test_package_wrappers(self):
        cases = [
            (["build-package", "knots"], ["build", ".#knots", "-L"], None),
            (["build-aoci-code"], ["build", ".#aoci-code", "-L", "--impure"], "1"),
        ]
        for recipes, args, unfree in cases:
            with self.subTest(recipes=recipes):
                args.insert(2, "--accept-flake-config")
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
                if tool == "nixos-rebuild":
                    args.append("--accept-flake-config")
                elif tool == "system-manager":
                    args.extend(
                        ["--sudo", "--nix-option", "accept-flake-config", "true"]
                    )
                else:
                    args.extend(["--option", "accept-flake-config", "true"])
                self.assert_call([recipe, hostile], tool, args)
        self.assert_call(
            ["build-package", hostile, "--out-link", hostile],
            "nix",
            [
                "build",
                f".#{hostile}",
                "--accept-flake-config",
                "-L",
                "--out-link",
                hostile,
            ],
        )
        self.assert_call(
            ["check-home-manager", hostile],
            "systemctl",
            ["is-active", "--quiet", f"home-manager-{hostile}.service"],
        )
        calls = self.run_recipe("build-system-manager", hostile, hostile)
        self.assertEqual(calls[0]["args"][2], f".#{hostile}")
        self.assertEqual(calls[1]["args"], [
            "is-active", "--quiet", f"home-manager-{hostile}.service",
        ])
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
            "build-aoci-code",
        ):
            with self.subTest(recipe=recipe):
                self.assertEqual(len(self.run_recipe(recipe, success=False)), 1)

    def test_unfree_permission_does_not_leak(self):
        calls = self.run_recipe("build-aoci-code", "build-package", "knots")
        self.assertEqual([call["unfree"] for call in calls], ["1", None])

    def test_removed_workflows_are_unavailable(self):
        for recipe in (
            "build-alvr", "alvr-android-shell", "prepare-alvr-android",
            "build-alvr-android", "verify-alvr-android", "test-alvr-android",
        ):
            with self.subTest(recipe=recipe):
                self.assertEqual(self.run_recipe(recipe, success=False), [])

    def test_dotfiles_clone_when_absent(self):
        self.assert_call(
            ["update-dotfiles"],
            "git",
            ["clone", "git@github.com:gkzhb/dotfiles.git", "dotfiles"],
        )

    def test_dotfiles_pull_existing_checkout(self):
        dotfiles = self.root / "dotfiles"
        dotfiles.mkdir()
        for worktree in (False, True):
            with self.subTest(worktree=worktree):
                marker = dotfiles / ".git"
                if worktree:
                    marker.write_text("gitdir: /some/worktree\n")
                else:
                    marker.mkdir()
                self.assert_call(
                    ["update-dotfiles"], "git", ["-C", "dotfiles", "pull", "--ff-only", "--no-rebase"]
                )
                if worktree:
                    marker.unlink()
                else:
                    marker.rmdir()

    def test_dotfiles_reject_existing_non_checkout(self):
        dotfiles = self.root / "dotfiles"
        dotfiles.mkdir()
        self.assertEqual(self.run_recipe("update-dotfiles", success=False), [])
        dotfiles.rmdir()
        dotfiles.write_text("preserve me")
        self.assertEqual(self.run_recipe("update-dotfiles", success=False), [])
        self.assertEqual(dotfiles.read_text(), "preserve me")
        dotfiles.unlink()
        dotfiles.symlink_to(self.root / "missing")
        self.assertEqual(self.run_recipe("update-dotfiles", success=False), [])
        self.assertTrue(dotfiles.is_symlink())

    def test_dotfiles_git_failures_propagate(self):
        self.env["ROUTING_EXIT"] = "42"
        self.assertEqual(len(self.run_recipe("update-dotfiles", success=False)), 1)
        (self.root / "dotfiles/.git").mkdir(parents=True)
        self.assertEqual(len(self.run_recipe("update-dotfiles", success=False)), 1)

    def test_maintenance_commands_accept_flake_config(self):
        cases = [
            ("update", ["flake", "update", "--accept-flake-config"]),
            (
                "update-edge",
                ["flake", "update", "--accept-flake-config", "nixpkgs-edge"],
            ),
            (
                "update-nix",
                [
                    "flake",
                    "update",
                    "--accept-flake-config",
                    "nixpkgs",
                    "nix-ld",
                    "sops-nix",
                    "home-manager",
                    "nix-darwin",
                    "system-manager",
                ],
            ),
            ("test-uv-config", ["eval", "--accept-flake-config", "--impure", "--json", "--file", "scripts/tests/test-uv-config.nix"]),
            ("format", ["fmt", "--accept-flake-config"]),
            ("check-format", ["flake", "check", "--accept-flake-config"]),
            (
                "install-hooks",
                ["develop", "--accept-flake-config", "--command", "true"],
            ),
        ]
        for recipe, args in cases:
            with self.subTest(recipe=recipe):
                self.assert_call([recipe], "nix", args)


if __name__ == "__main__":
    unittest.main()
