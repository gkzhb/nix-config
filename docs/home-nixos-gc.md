# home-nixos 系统代际自动清理

[`hosts/home-nixos/configuration.nix`](../hosts/home-nixos/configuration.nix) 启用 NixOS 自带的 `nix-gc.timer`：每周一 00:00（主机本地时区）起，随机延迟最多 1 小时。错过运行时间会补跑；激活后不要假设一定要等到下周才执行。

服务先对 `/nix/var/nix/profiles/system` 执行 `nix-env --delete-generations +5`，成功后才由 NixOS 内置任务运行 `nix-collect-garbage`（不带 `-d`）。正常情况下保留含当前在内的最近 5 代；若已回滚，Nix 额外保留比当前更新的代际。删掉代际就不能再通过原代际直接回滚。不会删除其他 Nix profile 的历史代际或 `/home` 数据；仍被其他 profiles、构建结果或运行中进程引用的 store 路径不会被回收。

## 先预览，再选择如何执行

```sh
sudo nix-env --profile /nix/var/nix/profiles/system --list-generations
sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +5 --dry-run
```

如果不等新配置激活就要清理，下面两步会实际删除旧代际并回收空间：

```sh
sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +5 &&
  sudo nix-store --gc
```

激活定时任务并检查：

```sh
sudo just build-nixos home-nixos
systemctl list-timers --all nix-gc.timer
sudo journalctl -u nix-gc.service
```

激活后手动触发同一套清理，用 `sudo systemctl start nix-gc.service`。可用 `df -h / /boot` 对比空间；Nix GC 回收的是 store，systemd-boot 的 EFI 文件不是 Nix GC 的清理对象。
