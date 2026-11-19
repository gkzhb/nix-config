"""Test the deploy hook with a fake systemctl; never touch real services."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parents[1] / "certbot-deploy.sh"
LINEAGE = "/etc/letsencrypt/live/byte.gkzhb.top"


class DeployHookTest(unittest.TestCase):
    def run_hook(self, lineage=LINEAGE, fail=""):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "calls"
            systemctl = root / "systemctl"
            systemctl.write_text(
                '#!/bin/sh\nprintf \'%s\\n\' "$*" >> "$CALL_LOG"\n'
                'if [ "$1" = "$FAIL_COMMAND" ]; then exit 7; fi\n'
            )
            systemctl.chmod(0o755)
            env = {**os.environ, "CALL_LOG": str(log), "FAIL_COMMAND": fail}
            env.pop("RENEWED_LINEAGE", None)
            if lineage is not None:
                env["RENEWED_LINEAGE"] = lineage
            result = subprocess.run(
                ["bash", str(HOOK), str(systemctl)],
                env=env,
                check=False,
                capture_output=True,
                text=True,
            )
            return (
                result.returncode,
                log.read_text().splitlines() if log.exists() else [],
            )

    def test_success_uses_operations_that_do_not_start_inactive_services(self):
        self.assertEqual(
            self.run_hook(),
            (0, ["try-reload-or-restart nginx.service", "try-restart dolt.service"]),
        )

    def test_unrelated_or_missing_lineage_does_nothing(self):
        for lineage in (None, "", "/etc/letsencrypt/live/other.example"):
            with self.subTest(lineage=lineage):
                self.assertEqual(self.run_hook(lineage), (0, []))

    def test_nginx_failure_does_not_prevent_dolt_refresh(self):
        self.assertEqual(
            self.run_hook(fail="try-reload-or-restart"),
            (7, ["try-reload-or-restart nginx.service", "try-restart dolt.service"]),
        )

    def test_dolt_failure_is_reported(self):
        self.assertEqual(self.run_hook(fail="try-restart")[0], 7)


if __name__ == "__main__":
    unittest.main()
