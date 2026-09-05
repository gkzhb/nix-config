"""Workspace/verification regression tests; fake SDK tools, no real signing or device."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

DRIVER = sys.argv.pop(1)


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.work = self.root / "work with spaces"
        src = self.root / "source"
        (src / ".cargo").mkdir(parents=True)
        (src / "alvr/xtask/src").mkdir(parents=True)
        (src / "Cargo.lock").write_text("pinned lockfile\n")
        (src / "Cargo.toml").write_text('[workspace.package]\nversion = "21.0.0-dev12"\n')
        (src / ".cargo/config.toml").write_text('[alias]\nxtask = "run -p alvr_xtask --"\n')
        (src / "alvr/xtask/src/build.rs").write_text(
            'cmd!(sh, "cargo apk build --target-dir={target_dir} {flags_ref...}")\n'
        )
        openvr = self.root / "openvr"
        openvr.mkdir()
        (openvr / "header").write_text("pinned OpenVR\n")
        loader = self.root / "loader.aar"
        with zipfile.ZipFile(loader, "w") as z:
            z.writestr(
                "prefab/modules/openxr_loader/libs/android.arm64-v8a/libopenxr_loader.so",
                b"fake loader",
            )
        vendor = self.root / "vendor-config"
        vendor.write_text('[source.crates-io]\nreplace-with = "pinned"\n')
        tools = self.root / "build-tools"
        tools.mkdir()
        # Signature checking itself is tested by the actual SDK, not these fixtures.
        for name, script in {
            "apksigner": '#!/bin/sh\nprintf "fake signer check\\n"\n',
            "aapt": '#!/bin/sh\nprintf "%s\\n" "package: name=\'alvr.client.dev\' versionName=\'21.0.0-dev12\'" "sdkVersion:\'28\'" "targetSdkVersion:\'32\'"\n',
        }.items():
            path = tools / name
            path.write_text(script)
            path.chmod(0o755)
        self.env = os.environ | {
            "ALVR_ANDROID_REV": "test-revision",
            "ALVR_ANDROID_SRC": str(src),
            "ALVR_ANDROID_OPENVR": str(openvr),
            "ALVR_ANDROID_OPENXR": str(loader),
            "ALVR_ANDROID_VENDOR_CONFIG": str(vendor),
            "ALVR_ANDROID_BUILD_TOOLS": str(tools),
        }

    def run_driver(self, mode, *, ok=True, work=None):
        result = subprocess.run(
            [DRIVER, mode, str(work or self.work)],
            env=self.env,
            capture_output=True,
            text=True,
        )
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_prepare_idempotent_preserves_edits(self):
        self.run_driver("prepare")
        script = (self.work / "alvr/xtask/src/build.rs").read_text()
        self.assertIn("cargo apk build --target-dir", script)
        self.assertNotIn("cargo apk build --locked", script)
        self.assertIn("[alias]", (self.work / ".cargo/config.toml").read_text())
        self.assertIn("[source.crates-io]", (self.work / ".cargo/config.toml").read_text())
        self.assertTrue((self.work / "openvr/header").is_file())
        (self.work / "local-edit").write_text("keep me")
        self.run_driver("prepare")
        self.assertEqual((self.work / "local-edit").read_text(), "keep me")

    def test_refuses_foreign_directory(self):
        self.work.mkdir()
        sentinel = self.work / "keep"
        sentinel.write_text("untouched")
        self.run_driver("prepare", ok=False)
        self.assertEqual(sentinel.read_text(), "untouched")

    def test_rejects_changed_inputs_and_lock(self):
        self.run_driver("prepare")
        self.env["ALVR_ANDROID_REV"] = "different"
        self.run_driver("prepare", ok=False)
        self.env["ALVR_ANDROID_REV"] = "test-revision"
        (self.work / "Cargo.lock").write_text("changed")
        self.run_driver("prepare", ok=False)

    def test_failed_prepare_is_cleaned(self):
        self.env["ALVR_ANDROID_OPENXR"] = str(self.root / "absent.aar")
        self.run_driver("prepare", ok=False)
        self.assertFalse(self.work.exists())
        self.assertEqual(list(self.root.glob("*.prepare.*")), [])

    def test_store_workspace_rejected(self):
        self.run_driver("prepare", ok=False, work="/nix/store/forbidden-alvr-workspace")

    def make_apk(self, extra_lib=None):
        apk = self.work / "build/alvr_client_android/alvr_client_android.apk"
        apk.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(apk, "w") as z:
            for name in ["libalvr_client_openxr.so", "libopenxr_loader.so"]:
                z.writestr("lib/arm64-v8a/" + name, b"\x7fELF\x02\x01" + b"\0" * 12 + b"\xb7\0")
            if extra_lib:
                z.writestr(extra_lib, b"fixture")

    def test_verify_arm64_only(self):
        self.run_driver("prepare")
        self.run_driver("verify", ok=False)
        self.make_apk()
        self.run_driver("verify")
        self.make_apk("lib/x86_64/wrong.so")
        self.run_driver("verify", ok=False)
        self.make_apk("lib/arm64-v8a/not-an-elf.so")
        self.run_driver("verify", ok=False)


if __name__ == "__main__":
    unittest.main()
