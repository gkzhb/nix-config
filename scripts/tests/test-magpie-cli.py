"""Smoke-test Magpie in temporary XDG directories, with no providers or activation."""

import json
import os
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path


def main():
    binary = str(Path(sys.argv[1]).resolve())
    with tempfile.TemporaryDirectory(prefix="magpie-smoke-") as directory:
        root = Path(directory)
        # Do not inherit provider keys, proxy credentials, or agent sign-ins.
        env = {
            "HOME": directory,
            "PATH": os.defpath,
            "XDG_CONFIG_HOME": str(root / "config"),
            "XDG_CACHE_HOME": str(root / "cache"),
            "XDG_DATA_HOME": str(root / "data"),
            "XDG_STATE_HOME": str(root / "state"),
            "MAGPIE_NO_ACCOUNTS": "1",
            "DO_NOT_TRACK": "1",
            "MAGPIE_DRAIN": "2s",
        }
        help_result = subprocess.run(
            [binary, "--help"], check=False, env=env, cwd=root, capture_output=True, text=True, timeout=15,
        )
        assert help_result.returncode == 0, "Magpie help failed"
        assert "serve" in help_result.stdout + help_result.stderr, "serve command missing"
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        env["MAGPIE_ADDR"] = f"127.0.0.1:{port}"
        client = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        old_umask = os.umask(0o077)
        try:
            with (root / "server.log").open("w") as log:
                process = subprocess.Popen(
                    [binary, "serve"], env=env, cwd=root, stdout=log, stderr=subprocess.STDOUT,
                )
                try:
                    deadline = time.monotonic() + 30
                    while True:
                        assert process.poll() is None, "Magpie exited before becoming ready"
                        try:
                            with socket.create_connection(("127.0.0.1", port), timeout=0.5):
                                break
                        except OSError:
                            if time.monotonic() >= deadline:
                                raise AssertionError("Magpie did not listen within 30 seconds")
                            time.sleep(0.1)
                    health = subprocess.run(
                        [binary, "healthcheck"], check=False, env=env, cwd=root, capture_output=True, timeout=10,
                    )
                    assert health.returncode == 0, "Magpie healthcheck failed"
                    request = urllib.request.Request(
                        f"http://127.0.0.1:{port}/v1/models",
                        headers={"Authorization": "Bearer magpie"},
                    )
                    with client.open(request, timeout=10) as response:
                        models = json.load(response)
                        assert response.status == 200
                    assert models.get("object") == "list", "OpenAI model list unavailable"
                    assert isinstance(models.get("data"), list), "invalid model data"
                    # No inference or provider setup is part of this smoke test.
                    process.terminate()
                    process.wait(timeout=15)
                    # Magpie drains, then re-raises SIGTERM. systemd considers
                    # SIGTERM a clean exit for Type=simple; Python reports -15.
                    assert process.returncode in (0, -signal.SIGTERM), (
                        f"Unexpected Magpie stop status: {process.returncode}"
                    )
                    log.flush()
                    stop_log = (root / "server.log").read_text()
                    assert "SIGTERM, finishing the requests in flight" in stop_log, (
                        "Magpie did not enter its graceful drain handler"
                    )
                    print("PASS: help, temporary-state serve, healthcheck, model list and SIGTERM drain")
                finally:
                    if process.poll() is None:
                        process.terminate()
                        try:
                            process.wait(timeout=15)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait(timeout=5)
        finally:
            os.umask(old_umask)


if __name__ == "__main__":
    main()
