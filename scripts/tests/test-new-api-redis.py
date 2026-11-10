#!/usr/bin/env python3
"""Exercise New API with shared Redis's config in temporary state only."""

import importlib.util
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile


def main():
    binary, redis_server, redis_cli, config, version = sys.argv[1:]
    config_text = Path(config).read_text()
    for line in ('bind 127.0.0.1', 'port 6379', 'protected-mode yes',
                 'supervised systemd', 'appendonly yes', 'appendfsync everysec'):
        assert line in config_text.splitlines(), line
    spec = importlib.util.spec_from_file_location(
        "newapi_smoke", Path(__file__).with_name("test-new-api.py")
    )
    smoke = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(smoke)
    env = os.environ.copy()
    for name in ("VERSION", "PORT", "SQL_DSN", "LOG_SQL_DSN",
                 "SESSION_SECRET", "CRYPTO_SECRET", "NODE_TYPE",
                 "FRONTEND_BASE_URL"):
        env.pop(name, None)

    with tempfile.TemporaryDirectory(prefix="newapi-redis-test-") as directory:
        root = Path(directory)
        notify_path = str(root / "notify.sock")
        # Never use the production listener or database: override only the port.
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
        env["REDIS_CONN_STRING"] = f"redis://127.0.0.1:{port}/0"
        # The actual production config must send systemd READY=1.
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as notify:
            notify.bind(notify_path)
            notify.settimeout(20)
            with (root / "redis.log").open("w+") as log:
                process = None
                try:
                    for attempt in range(2):
                        process = subprocess.Popen(
                            [redis_server, config, "--port", str(port)],
                            cwd=root, env={
                                **env, "NOTIFY_SOCKET": notify_path,
                                "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8",
                            },
                            stdout=log, stderr=subprocess.STDOUT,
                        )
                        while b"READY=1" not in notify.recv(4096):
                            if process.poll() is not None:
                                raise RuntimeError("Redis exited before reporting readiness")
                        assert process.poll() is None, "Redis exited after readiness"
                        command = [redis_cli, "-h", "127.0.0.1", "-p", str(port)]
                        assert subprocess.check_output(command + ["PING"], text=True).strip() == "PONG"
                        if attempt == 0:
                            subprocess.check_call(command + ["SET", "integration:seed", "preserved"], stdout=subprocess.DEVNULL)
                            subprocess.check_call(command + ["-n", "1", "SET", "other-app:seed", "also-preserved"], stdout=subprocess.DEVNULL)
                            smoke.smoke_server(binary, version, env.copy(), "")
                        else:
                            assert subprocess.check_output(command + ["GET", "integration:seed"], text=True).strip() == "preserved"
                            assert subprocess.check_output(command + ["-n", "1", "GET", "other-app:seed"], text=True).strip() == "also-preserved"
                            smoke.smoke_server(
                                binary, version, env.copy(),
                                "?_pragma=busy_timeout(30000)&_pragma=journal_mode(WAL)&_txlock=immediate",
                            )
                        process.terminate()
                        assert process.wait(timeout=15) == 0
                        process = None
                    print("Redis: shared TCP, systemd readiness, multi-DB AOF restart and New API integration passed")
                except BaseException:
                    log.flush()
                    log.seek(0)
                    print(log.read(), file=sys.stderr)
                    raise
                finally:
                    if process is not None and process.poll() is None:
                        process.terminate()
                        try:
                            process.wait(timeout=10)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait()


if __name__ == "__main__":
    main()
