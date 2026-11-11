#!/usr/bin/env python3
"""Set Dolt root credentials offline before opening any network listener."""

import csv
import io
import os
from pathlib import Path
import subprocess
import sys


def prepare(binary, secret_path):
    password = Path(secret_path).read_text().rstrip("\r\n")
    if len(password) < 24 or any(ord(c) < 32 for c in password):
        raise RuntimeError("Dolt root password must be at least 24 characters without control characters")

    # The local data-directory owner has offline SQL superuser access. No
    # password is passed via argv, persisted SQL files or journal output.
    env = {k: v for k, v in os.environ.items() if not k.startswith("DOLT_")}
    env["DOLT_DISABLE_UPDATE_CHECK"] = "true"
    command = [binary, "--data-dir", ".", "--doltcfg-dir", ".doltcfg", "sql", "--result-format", "csv"]

    def sql(query):
        result = subprocess.run(command, input=query, env=env, text=True, capture_output=True, timeout=60)
        if result.returncode:
            # Dolt errors may echo the SQL containing the password.
            raise RuntimeError("Offline Dolt root provisioning failed; listener will not start")
        return list(csv.DictReader(io.StringIO(result.stdout)))

    def quote(value):
        return "'" + value.replace("\\", "\\\\").replace("'", "''") + "'"

    hosts = {row["Host"] for row in sql("SELECT Host FROM mysql.user WHERE User='root';")}
    # Update all pre-existing root host variants, not just root@%, so an old
    # root@localhost with an empty password cannot bypass the new credential.
    for host in sorted(hosts | {"localhost", "%"}):
        account = "'root'@" + quote(host)
        sql(
            f"CREATE USER IF NOT EXISTS {account} IDENTIFIED BY {quote(password)};"
            f"ALTER USER {account} IDENTIFIED BY {quote(password)};"
            f"GRANT ALL PRIVILEGES ON *.* TO {account} WITH GRANT OPTION;"
        )
    # Offline SQL injects a virtual passwordless root@localhost superuser for
    # the data-directory owner; it is not a persisted network account. Validate
    # the explicitly provisioned root@% instead of mistaking that local-only row.
    rows = sql("SELECT authentication_string FROM mysql.user WHERE User='root' AND Host='%';")
    if len(rows) != 1 or not rows[0]["authentication_string"]:
        raise RuntimeError("Dolt root authentication validation failed; listener will not start")
    print("Dolt root password provisioned offline; authentication required for all root hosts")


if __name__ == "__main__":
    try:
        prepare(sys.argv[1], Path(os.environ["CREDENTIALS_DIRECTORY"]) / "root-password")
    except Exception:
        # Do not print exception details that could include secret contents.
        print("Dolt credential preparation failed; refusing to start network listener", file=sys.stderr)
        sys.exit(1)
