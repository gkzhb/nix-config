# System Manager 历史版本自动清理

共享模块位于 `modules/system-manager/garbage-collection.nix`，当前已在
`gkzhb-vps`、`devbox`、`mido` 启用。模块只管理清理任务，不修改宿主的 Nix daemon。

## 默认行为

- 每周运行一次（systemd `weekly`，本地时区周一 00:00 起，随机延迟最多 1 小时）。
- 保留包含当前代际在内的最近 **5 代**；若当前曾回滚，Nix 也会保留比当前更新的代际。
- 先对 System Manager 的 profile 执行 `nix-env --delete-generations +5`。
- 只有清理代际成功后，才执行 `nix-store --gc`。
- 以 root 执行，程序使用 `config.nix.package` 的绝对路径，不依赖交互式 PATH。
- `Persistent = true`：错过执行时间会在 timer 恢复后补跑，不会为每次错过的周次分别执行。
- profile 不存在时跳过，不会启动空 profile 的清理。

删除旧代际会失去对应版本的直接回滚能力。GC 是整个 Nix store 范围的回收，
但只删除无引用对象；**不会删除其他 profile 的历史代际**，也不会删除数据库或用户文件。
其他 GC roots（例如构建结果 `result` 或仍运行的旧进程）可能继续保留部分旧依赖。

不使用 `nix-collect-garbage -d`，因为 System Manager 的 profile 位于
`/nix/var/nix/profiles/system-manager-profiles/system-manager`，需要显式指定，
且不希望顺带清理其他工具的 profile 历史。

## 在其他主机复用

在 System Manager 的 `modules` 列表中加入共享模块（相对路径按入口位置调整）：

```nix
modules = [
  ./modules/system-manager/garbage-collection.nix
  {
    services.system-manager-gc.enable = true;
  }
];
```

主机可以覆盖默认值：

```nix
services.system-manager-gc = {
  enable = true;
  keepGenerations = 5;
  onCalendar = "Sun *-*-* 03:00:00";
  randomizedDelaySec = "30m";
  # 只有使用自定义 profile 位置时才需要覆盖：
  # profile = "/nix/var/nix/profiles/custom-system-manager";
};
```

禁用：`services.system-manager-gc.enable = false;`。

## 激活与检查

配置不会仅因文件被修改就开始运行，需要在对应主机执行构建并激活：

```sh
just build-system-manager gkzhb-vps
# 其他主机使用 devbox 或 mido
```

**注意：首次激活可能因 Persistent 补跑而很快执行清理，不一定等到下周。**

激活后检查：

```sh
systemctl list-timers --all system-manager-gc.timer
systemctl status system-manager-gc.timer
sudo journalctl -u system-manager-gc.service
sudo nix-env --profile /nix/var/nix/profiles/system-manager-profiles/system-manager --list-generations
```

立即手动运行一次（会实际删除旧代际并 GC）：

```sh
sudo systemctl start system-manager-gc.service
```

只预览代际删除、不执行：

```sh
sudo nix-env --profile /nix/var/nix/profiles/system-manager-profiles/system-manager --delete-generations +5 --dry-run
```

## 回归验证

只求值模块和生成的 systemd 单元，不构建、激活或清理真实 store：

```sh
just test-system-manager-gc
```

另外验证三台主机的实际接入（可能需要下载主机的间接 flake 依赖）：

```sh
nix eval --accept-flake-config --impure --json --file scripts/tests/test-system-manager-gc-hosts.nix
```
