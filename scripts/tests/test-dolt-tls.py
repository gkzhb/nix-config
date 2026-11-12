#!/usr/bin/env python3
"""Verify Dolt TLS/auth with temporary data and a real MySQL TLS client."""

import hashlib
import os
from pathlib import Path
import re
import socket
import ssl
import struct
import subprocess
import sys
import tempfile
import time


def receive(stream, size):
    result = b""
    while len(result) < size:
        chunk = stream.recv(size - len(result))
        if not chunk:
            raise RuntimeError("Incomplete MySQL packet")
        result += chunk
    return result


def packet(stream):
    header = receive(stream, 4)
    return receive(stream, int.from_bytes(header[:3], "little"))


def send(stream, payload, sequence):
    stream.sendall(len(payload).to_bytes(3, "little") + bytes([sequence]) + payload)


def connect(port, context, hostname, password, use_tls=True):
    stream = socket.create_connection(("127.0.0.1", port), timeout=5)
    try:
        greeting = packet(stream)
        end = greeting.index(b"\0", 1)
        offset = end + 1 + 4
        salt = greeting[offset:offset + 8]
        offset += 8 + 1 + 2
        charset = greeting[offset]
        offset += 1 + 2 + 2
        salt_len = greeting[offset]
        offset += 1 + 10
        salt += greeting[offset:offset + max(13, salt_len - 8)].rstrip(b"\0")
        plugin = greeting[offset + max(13, salt_len - 8):].split(b"\0", 1)[0]
        assert plugin in (b"mysql_native_password", b""), plugin
        flags = 0x00000001 | 0x00000008 | 0x00000200 | 0x00008000 | 0x00080000
        if use_tls:
            flags |= 0x00000800
        prefix = struct.pack("<IIB23s", flags, 16777216, charset, b"\0" * 23)
        sequence = 1
        if use_tls:
            send(stream, prefix, sequence)
            stream = context.wrap_socket(stream, server_hostname=hostname)
            assert stream.cipher()
            sequence += 1
        first = hashlib.sha1(password.encode()).digest()
        token = bytes(a ^ b for a, b in zip(first, hashlib.sha1(salt + hashlib.sha1(first).digest()).digest())) if password else b""
        send(stream, prefix + b"root\0" + bytes([len(token)]) + token + b"mysql\0mysql_native_password\0", sequence)
        response = packet(stream)
        if response[0] == 0xff:
            raise PermissionError("Dolt rejected MySQL connection")
        assert response[0] == 0x00, "Unexpected authentication response"
        return stream
    except BaseException:
        stream.close()
        raise


def query(stream):
    send(stream, b"\x03SELECT 'encrypted-query-result' AS marker", 0)
    first = packet(stream)
    assert first[0] != 0xff, "TLS SQL query failed"
    columns = first[0]
    for _ in range(columns):
        packet(stream)
    assert packet(stream)[0] == 0xfe, "Missing column terminator"
    row = packet(stream)
    assert b"encrypted-query-result" in row, "Encrypted result missing"
    assert packet(stream)[0] == 0xfe, "Missing row terminator"


def main():
    binary, config_path, credentials_path, ca_path, hostname = sys.argv[1:]
    config = Path(config_path).read_text()
    assert re.search(r"require_secure_transport:\s*true", config)
    assert re.search(r"host:\s*['\"]?0\.0\.0\.0", config)
    assert "${CREDENTIALS_DIRECTORY}/tls-key" in config
    credentials = Path(credentials_path).resolve()
    password = (credentials / "root-password").read_text().rstrip("\r\n")
    context = ssl.create_default_context(cafile=None if ca_path == "-" else ca_path)
    with tempfile.TemporaryDirectory(prefix="dolt-tls-test-") as directory:
        root = Path(directory)
        env = {k: v for k, v in os.environ.items() if not k.startswith(("DOLT_", "BEADS_", "MYSQL_"))}
        env.update(HOME=str(root), XDG_RUNTIME_DIR=str(root), CREDENTIALS_DIRECTORY=str(credentials))
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
        test_config = root / "server.yaml"
        test_config.write_text(re.sub(r"port:\s*3307", f"port: {port}",
            config.replace("0.0.0.0", "127.0.0.1")
                  .replace("/home/zhanghaibin.zhb/scripts/services/dolt", str(root))
                  .replace("/run/dolt/dolt.sock", str(root / "dolt.sock"))))
        prepare = Path(__file__).resolve().parents[1] / "dolt-prepare-root.py"
        subprocess.run([sys.executable, str(prepare), binary], cwd=root, env=env, check=True)
        with (root / "server.log").open("w+") as log:
            process = subprocess.Popen([binary, "sql-server", "--config", str(test_config), "--skip-root-user-initialization"],
                                       cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 20
                while True:
                    assert process.poll() is None, "Dolt exited before TLS readiness"
                    try:
                        stream = connect(port, context, hostname, password)
                        break
                    except ConnectionRefusedError:
                        assert time.monotonic() < deadline, "TLS startup timeout"
                        time.sleep(0.1)
                with stream:
                    query(stream)
                    version = stream.version()
                for kwargs in ({"use_tls": False}, {"password": "wrong-password"}, {"password": ""}):
                    args = {"password": password, **kwargs}
                    try:
                        rejected = connect(port, context, hostname, **args)
                    except (PermissionError, ConnectionError):
                        pass
                    else:
                        rejected.close()
                        raise AssertionError("Plaintext/incorrect credential accepted")
                for bad_context, bad_hostname in ((ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT), hostname),
                                                   (context, "wrong-hostname.invalid")):
                    try:
                        rejected = connect(port, bad_context, bad_hostname, password)
                    except ssl.SSLCertVerificationError:
                        pass
                    else:
                        rejected.close()
                        raise AssertionError("Untrusted CA or incorrect hostname accepted")
                print(f"Dolt TLS passed: {version}, encrypted SQL/results, plaintext/empty/wrong-password denial, CA and hostname verification")
            except BaseException:
                log.flush()
                log.seek(0)
                print(log.read()[-4000:], file=sys.stderr)
                raise
            finally:
                process.terminate()
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


if __name__ == "__main__":
    main()
