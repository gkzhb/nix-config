#!/usr/bin/env python3
"""Dolt credential regression using disposable state and random loopback ports."""

import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time


def main():
    binary, prepare_script = sys.argv[1:]
    prepare_script = str(Path(prepare_script).resolve())
    with tempfile.TemporaryDirectory(prefix="dolt-auth-test-") as directory:
        root = Path(directory)
        data = root / "data"
        data.mkdir(mode=0o700)
        credentials = root / "credentials"
        credentials.mkdir(mode=0o700)
        secret = credentials / "root-password"
        env = {k: v for k, v in os.environ.items() if not k.startswith(("DOLT_", "BEADS_", "MYSQL_"))}
        env.update(HOME=str(root), CREDENTIALS_DIRECTORY=str(credentials))
        prepare = [sys.executable, prepare_script, binary]

        for contents in (None, "", "short"):
            if contents is not None:
                secret.write_text(contents)
            result = subprocess.run(prepare, cwd=data, env=env, capture_output=True, text=True)
            assert result.returncode != 0, "Missing/weak secret must fail closed"
        passwords = ["initial-test-only-password-0123456789", "rotated-test-only-password-9876543210"]
        for iteration, password in enumerate(passwords):
            secret.write_text(password)
            secret.chmod(0o600)
            result = subprocess.run(prepare, cwd=data, env=env, capture_output=True, text=True)
            assert result.returncode == 0, result.stderr
            assert password not in result.stdout + result.stderr
            with socket.socket() as listener:
                listener.bind(("127.0.0.1", 0))
                port = listener.getsockname()[1]
            # Test loopback, never expose a random test DB to the network.
            process = subprocess.Popen(
                [binary, "sql-server", "--host", "127.0.0.1", "--port", str(port),
                 "--data-dir", ".", "--doltcfg-dir", ".doltcfg", "--socket", str(root / "dolt.sock"),
                 "--skip-root-user-initialization"],
                cwd=data, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            command = [binary, "--host", "127.0.0.1", "--port", str(port), "--user", "root",
                       "--no-tls", "--use-db", "mysql", "sql"]

            def query(pw, sql):
                return subprocess.run(command, input=sql, cwd=root,
                                      env={**env, "DOLT_CLI_PASSWORD": pw},
                                      text=True, capture_output=True, timeout=15)

            try:
                deadline = time.monotonic() + 20
                while True:
                    assert process.poll() is None, "Dolt exited"
                    result = query(password, "SELECT 1;")
                    if result.returncode == 0:
                        break
                    assert time.monotonic() < deadline, "Dolt startup timed out"
                    time.sleep(0.1)
                for rejected in ("", "wrong-password", passwords[0] if iteration else "other"):
                    assert query(rejected, "SELECT 1;").returncode != 0, "Invalid password accepted"
                if iteration == 0:
                    result = query(password, "CREATE DATABASE seed; USE seed; CREATE TABLE data (id INT PRIMARY KEY); INSERT INTO data VALUES (42);")
                else:
                    result = query(password, "SELECT id FROM seed.data;")
                    assert "42" in result.stdout, "Password rotation lost data"
                assert result.returncode == 0, result.stderr
            finally:
                process.terminate()
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        print("Dolt: missing/weak password rejected; authenticated startup, empty/wrong password denial, rotation and data preservation passed")


if __name__ == "__main__":
    main()
