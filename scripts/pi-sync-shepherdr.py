#!/usr/bin/env python3
"""Render host-specific Shepherdr profiles without modifying the checkout."""

import argparse
import json
import os
from pathlib import Path
import re
import sys
import tempfile


PROFILES = ("general", "reviewer", "explorer")
MODEL = re.compile(r"[^/\s]+/\S+")


def read_object(path):
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(value, dict):
            raise ValueError("expected a JSON object")
        return value
    except ValueError as error:
        raise ValueError(f"{path}: {error}") from error


def render_profiles(templates, catalog, models):
    if not isinstance(models, dict) or set(models) != set(PROFILES):
        raise ValueError(f"expected models for {', '.join(PROFILES)}")
    providers = read_object(catalog).get("providers", {})
    if not isinstance(providers, dict):
        raise ValueError(f"{catalog}: expected a providers object")

    rendered = {}
    assets = {}
    for name in PROFILES:
        model = models[name]
        if not isinstance(model, str) or not MODEL.fullmatch(model):
            raise ValueError(f"{name}: expected a full provider/model ID")
        provider, model_id = model.split("/", 1)
        provider_config = providers.get(provider, {})
        entries = (
            provider_config.get("models", [])
            if isinstance(provider_config, dict)
            else []
        )
        if not isinstance(entries, list) or not any(
            isinstance(entry, dict)
            and entry.get("id") == model_id
            and entry.get("type", "chat") == "chat"
            for entry in entries
        ):
            raise ValueError(
                f"{name}: model {model!r} is not a chat model in {catalog}"
            )

        directory = templates / "profiles" / name
        template = directory / "profile.json"
        profile = read_object(template)
        for field in ("description", "thinking"):
            if not isinstance(profile.get(field), str) or not profile[field].strip():
                raise ValueError(f"{template}: {field} must be a non-empty string")
        args = profile.get("pi_args", [])
        if not isinstance(args, list) or any(
            not isinstance(arg, str)
            or not arg
            or arg.split("=", 1)[0] in {"--model", "--provider"}
            for arg in args
        ):
            raise ValueError(f"{template}: invalid pi_args or redundant model override")
        for field in ("prompt", "prepare"):
            if field not in profile:
                continue
            filename = profile[field]
            if (
                not isinstance(filename, str)
                or not filename
                or filename in {".", "..", "profile.json"}
                or Path(filename).name != filename
                or not (directory / filename).is_file()
            ):
                raise ValueError(
                    f"{template}: {field} must name an existing sibling file"
                )
            assets[Path("profiles", name, filename)] = directory / filename
        profile["model"] = model
        rendered[Path("profiles", name, "profile.json")] = (
            json.dumps(profile, ensure_ascii=False, allow_nan=False, indent=2) + "\n"
        )
    return rendered, assets


def check_output(output, templates, rendered, assets):
    agent = output.parent
    agent_dir = os.environ.get("PI_CODING_AGENT_DIR")
    if agent_dir and Path(agent_dir).expanduser().resolve() != agent.resolve():
        raise ValueError("PI_CODING_AGENT_DIR differs from this Home Manager profile")
    source, dest = templates.resolve(), output.resolve()
    if source.is_relative_to(dest) or dest.is_relative_to(source):
        raise ValueError("refusing to render into or over the template directory")

    directories = [agent.parent, agent, output, output / "profiles"]
    directories.extend(output / "profiles" / name for name in PROFILES)
    for directory in directories:
        if directory.is_symlink() or (directory.exists() and not directory.is_dir()):
            raise ValueError(f"{directory} must be a real directory")
    for relative in (*rendered, Path(".profiles-initialized")):
        target = output / relative
        if target.is_symlink() or (target.exists() and not target.is_file()):
            raise ValueError(f"{target} must be a regular file")
    for relative in assets:
        target = output / relative
        if not target.is_symlink() and target.exists():
            raise ValueError(f"refusing to replace a non-symlink asset: {target}")
    return directories


def write_atomic(path, content):
    if path.is_file() and path.read_text(encoding="utf-8") == content:
        return
    with tempfile.TemporaryDirectory(dir=path.parent, prefix=".render-") as temp:
        staged = Path(temp) / path.name
        with open(staged, "w", encoding="utf-8", opener=private_file) as handle:
            handle.write(content)
        os.replace(staged, path)


def private_file(path, flags):
    return os.open(path, flags, 0o600)


def sync(templates, catalog, output, models, *, check=False):
    templates = templates.absolute()
    rendered, assets = render_profiles(templates, catalog, models)
    directories = check_output(output, templates, rendered, assets)
    if check:
        return
    for directory in directories:
        directory.mkdir(mode=0o700, exist_ok=True)
    for relative, source in assets.items():
        target = output / relative
        if target.is_symlink() and target.readlink() == source:
            continue
        with tempfile.TemporaryDirectory(dir=target.parent, prefix=".render-") as temp:
            staged = Path(temp) / target.name
            staged.symlink_to(source)
            os.replace(staged, target)
    for relative, content in rendered.items():
        write_atomic(output / relative, content)
    write_atomic(output / ".profiles-initialized", "1\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--templates", type=Path, required=True)
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--models", required=True)
    parser.add_argument("--check", action="store_true", help="validate without writing")
    args = parser.parse_args()
    try:
        sync(
            args.templates,
            args.catalog,
            args.output,
            json.loads(args.models),
            check=args.check,
        )
    except (OSError, ValueError) as error:
        sys.exit(f"pi-sync-shepherdr: {error}")
    if not args.check:
        print(f"Rendered Shepherdr profiles in {args.output}")


if __name__ == "__main__":
    main()
