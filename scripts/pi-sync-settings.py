#!/usr/bin/env python3
"""Merge checkout settings and Nix model defaults into Pi's writable settings."""

import argparse
import json
import os
from pathlib import Path
import sys
import tempfile


def object_from_json(text):
    def reject_constant(value):
        raise ValueError(f"invalid JSON constant: {value}")

    data = json.loads(text, parse_constant=reject_constant)
    if not isinstance(data, dict):
        raise ValueError("expected a JSON object")
    return data


def read_object(path):
    try:
        return object_from_json(path.read_text(encoding="utf-8"))
    except ValueError as error:
        raise ValueError(f"{path}: {error}") from error


def merge(base, overlay):
    """Merge objects recursively; arrays, scalars and null replace wholesale."""
    result = base.copy()
    for key, value in overlay.items():
        if isinstance(result.get(key), dict) and isinstance(value, dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = value
    return result


def sync(settings, shared, overrides, source, *, check=False):
    if settings.parent.is_symlink() or settings.parent.parent.is_symlink():
        raise ValueError("refusing to write through a symlinked .pi or agent directory")
    agent_dir = os.environ.get("PI_CODING_AGENT_DIR")
    if (
        agent_dir
        and Path(agent_dir).expanduser().resolve() != settings.parent.resolve()
    ):
        raise ValueError("PI_CODING_AGENT_DIR differs from this Home Manager profile")
    if settings.is_symlink():
        # Preflight may inspect the old generation's source. Live writes still
        # refuse any symlink; Home Manager must unlink it before migration.
        if not (check and source is not None and settings.readlink() == source):
            raise ValueError(
                f"{settings} is a symlink; back it up and remove the old mapping first"
            )
        local = read_object(source)
    elif settings.exists():
        if not settings.is_file():
            raise ValueError(f"{settings} is not a regular file")
        if source is not None:
            raise ValueError(
                f"{settings} already exists; --from is only for initial migration"
            )
        local = read_object(settings)
    else:
        local = read_object(source) if source is not None else {}
    result = merge(merge(local, read_object(shared)), overrides)
    payload = json.dumps(result, ensure_ascii=False, allow_nan=False, indent=2) + "\n"
    if check:
        return

    settings.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(
            dir=settings.parent,
            prefix=".settings.",
            encoding="utf-8",
            mode="w",
            delete=False,
        ) as temp:
            temp_path = Path(temp.name)
            temp.write(payload)
        os.replace(temp_path, settings)
    finally:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--settings", type=Path, required=True, help=argparse.SUPPRESS)
    parser.add_argument("--shared", type=Path, required=True, help=argparse.SUPPRESS)
    parser.add_argument("--overrides", required=True, help=argparse.SUPPRESS)
    parser.add_argument(
        "--from", dest="source", type=Path, help="seed missing settings from a backup"
    )
    parser.add_argument("--check", action="store_true", help="validate without writing")
    args = parser.parse_args()
    try:
        sync(
            args.settings,
            args.shared,
            object_from_json(args.overrides),
            args.source,
            check=args.check,
        )
    except (OSError, ValueError) as error:
        sys.exit(f"pi-sync-settings: {error}")
    if not args.check:
        print(f"Synced {args.settings}")


if __name__ == "__main__":
    main()
