#!/usr/bin/env python3
"""Smoke-test the packaged binary in a Nix build sandbox, without provider keys."""

import json
import os
from pathlib import Path
import re
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request


def main():
    binary, version = sys.argv[1:]
    env = os.environ.copy()
    for name in (
        "VERSION", "PORT", "SQL_DSN", "LOG_SQL_DSN", "REDIS_CONN_STRING",
        "SESSION_SECRET", "CRYPTO_SECRET", "NODE_TYPE", "FRONTEND_BASE_URL",
    ):
        env.pop(name, None)

    assert subprocess.check_output(
        [binary, "--version"], env=env, text=True
    ).strip() == f"v{version}"
    assert "Usage:" in subprocess.check_output(
        [binary, "--help"], env=env, text=True
    )

    with tempfile.TemporaryDirectory(prefix="new-api-smoke-") as directory:
        root = Path(directory)
        env.update(
            HOME=directory,
            SQLITE_PATH=str(root / "new-api.db"),
            SESSION_SECRET="new-api-build-sandbox-test-only-secret",
            CRYPTO_SECRET="new-api-build-sandbox-test-only-crypto-secret",
            TRUSTED_PROXIES="none",
        )
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        base = f"http://127.0.0.1:{port}"
        client = urllib.request.build_opener(urllib.request.ProxyHandler({}))

        with (root / "server.log").open("w+") as log:
            process = subprocess.Popen(
                [binary, "--port", str(port), "--log-dir", str(root / "logs")],
                cwd=directory, env=env, stdout=log, stderr=subprocess.STDOUT,
            )
            try:
                deadline = time.monotonic() + 60
                while True:
                    if process.poll() is not None:
                        raise RuntimeError(f"server exited with {process.returncode}")
                    try:
                        with client.open(base + "/api/status", timeout=2) as response:
                            status = json.load(response)
                        break
                    except (urllib.error.URLError, TimeoutError):
                        if time.monotonic() >= deadline:
                            raise RuntimeError("server did not become ready within 60s")
                        time.sleep(0.2)

                assert status["success"] is True, status
                assert status["data"]["version"] == f"v{version}", status
                with client.open(base + "/", timeout=5) as response:
                    assert response.status == 200
                    assert "text/html" in response.headers["Content-Type"]
                    html = response.read().decode()
                assert re.search(r'<div\b[^>]*\bid="root"', html), "embedded frontend missing"
                asset = re.search(r'<script\b[^>]*\bsrc="(/(?:assets|static/js)/[^\"]+\.js)"', html)
                assert asset, "frontend JavaScript reference missing"
                with client.open(base + asset.group(1), timeout=5) as response:
                    assert response.status == 200
                    assert len(response.read()) > 100, "frontend JavaScript missing"

                with sqlite3.connect(root / "new-api.db") as database:
                    tables = {
                        row[0] for row in database.execute(
                            "SELECT name FROM sqlite_master WHERE type='table'"
                        )
                    }
                assert {"users", "channels", "tokens"} <= tables, tables
                print(f"new-api v{version}: version, help, API, frontend and SQLite passed")
            except BaseException:
                log.flush()
                log.seek(0)
                print(log.read(), file=sys.stderr)
                raise
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()


if __name__ == "__main__":
    main()
