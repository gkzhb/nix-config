#!/usr/bin/env python3
# cleanup old backup files
from __future__ import annotations

import argparse
import sys
from pathlib import Path

# 备份目录
BACKUP_ROOT = Path.home() / "backups"
# 保留最近备份数量
KEEP_COUNT = 5
# 需要清理的备份文件匹配模式
PATTERN = "*.backup.tgz"


def parse_args() -> argparse.Namespace:
    """解析命令行参数，返回脚本运行所需配置。"""
    parser = argparse.ArgumentParser(
        description="Clean old backup archives under ~/backups, keeping the newest N files per software directory."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Only print which files would be deleted, without actually deleting them.",
    )
    parser.add_argument(
        "--keep",
        type=int,
        default=KEEP_COUNT,
        help=f"How many recent backups to keep in each software directory (default: {KEEP_COUNT}).",
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=BACKUP_ROOT,
        help=f"Backup root directory (default: {BACKUP_ROOT}).",
    )
    return parser.parse_args()


def list_software_dirs(root: Path) -> list[Path]:
    """列出备份根目录下一层的所有软件目录。"""
    return sorted(path for path in root.iterdir() if path.is_dir())


def list_backup_files(directory: Path) -> list[Path]:
    """列出指定软件目录中的备份文件，并按修改时间从新到旧排序。"""
    return sorted(
        (path for path in directory.glob(PATTERN) if path.is_file()),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )


def main() -> int:
    """执行主流程：检查参数、扫描目录、删除旧备份并输出结果。"""
    args = parse_args()
    root = args.root.expanduser().resolve()
    keep = args.keep
    dry_run = args.dry_run

    if keep < 0:
        print("Error: --keep 不能小于 0", file=sys.stderr)
        return 1

    if not root.exists():
        print(f"Error: 备份目录不存在: {root}", file=sys.stderr)
        return 1

    if not root.is_dir():
        print(f"Error: 不是目录: {root}", file=sys.stderr)
        return 1

    software_dirs = list_software_dirs(root)
    if not software_dirs:
        print(f"未找到任何软件目录: {root}")
        return 0

    deleted_count = 0

    for software_dir in software_dirs:
        backups = list_backup_files(software_dir)
        old_backups = backups[keep:]

        if not old_backups:
            continue

        print(f"目录: {software_dir}")
        for backup in old_backups:
            action = "Would delete" if dry_run else "Deleted"
            print(f"  {action}: {backup}")
            if not dry_run:
                backup.unlink()
            deleted_count += 1

    if deleted_count == 0:
        if dry_run:
            print("Dry-run 完成，没有需要删除的备份。")
        else:
            print("没有需要删除的备份。")
    else:
        if dry_run:
            print(f"Dry-run 完成，共 {deleted_count} 个文件将被删除。")
        else:
            print(f"清理完成，共删除 {deleted_count} 个文件。")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
