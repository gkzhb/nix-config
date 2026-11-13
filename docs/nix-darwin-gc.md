# 每周 nix-darwin 历史代际清理

`gkzhb-MBP` 的 `org.nixos.nix-system-gc` LaunchDaemon 每周日 03:00（本机时间）以 root 运行。保留 **5 个历史版本 + 当前版本，共 6 代**，然后执行 Nix 垃圾回收。

- 配置：`hosts/gkzhb-mbp/garbage-collection.nix`
- 脚本：`scripts/nix-darwin-gc.sh`（构建进不可变 Nix Store，不让 root 执行用户可写的 checkout 文件）
- 仅使用 `nix-env --profile /nix/var/nix/profiles/system --delete-generations +6`；不使用 `nix-collect-garbage -d`，其他 profile 的历史不删除。
- Nix 在回滚状态下还会保留比当前代际新的代际，因此届时总数可能大于 6。
- profile 缺失/损坏或裁剪失败则停止，不继续 GC。不会创建新的代际或恢复已经删除的历史。
- 不运行 Mole、不清浏览器数据或 `.agents`；GC 只回收没有 GC root 引用的 Nix Store 路径。
- 不设置 RunAtLoad/KeepAlive：加载任务时不立即清理、不因失败循环重试。launchd 在睡眠期间错过日历任务会在唤醒后合并执行；关机错过的任务不保证补跑。

## 验证与启用

```fish
just test-nix-darwin-gc
just build-darwin gkzhb-MBP
sudo launchctl print system/org.nixos.nix-system-gc
```

`build-darwin` 会激活整份系统和 Home Manager 配置，先检查其他工作区改动。仅安装这个任务时，可以构建 `config.environment.launchDaemons."org.nixos.nix-system-gc.plist".source`，把生成的 plist 以 root:wheel / 0644 安装到 `/Library/LaunchDaemons/`，然后 `sudo launchctl bootstrap system ...`。后续整机激活会继续管理同名任务。

日志：`/var/log/nix-system-gc.log`、`/var/log/nix-system-gc.error.log`。删除的历史不能直接回滚。
