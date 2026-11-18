# 使用 Home Manager 管理 dotfiles

## 职责划分

- `nix-config` 管理软件安装、主机差异和软链接映射。
- `dotfiles/` 是独立 Git 工作区，管理可编辑的软件配置；外层仓库将其忽略，不作为 submodule 或 flake input。
- 配置内容与 Nix 映射分别提交到各自仓库，不要在外层仓库添加 `dotfiles/`。

初始化或更新工作区：

```sh
just update-dotfiles
```

目录不存在时 clone，存在时执行 `git pull --ff-only`。命令不会覆盖非 Git 路径，也不会自动 stash、reset 或丢弃本地修改。不要与裸仓库直接管理 HOME 的方案混用。

## 启用与映射

在 Home Manager 入口导入 `modules/home-manager/dotfiles.nix`，并配置：

```nix
{
  dotfiles = {
    enable = true;
    root = "/absolute/path/to/nix-config/dotfiles";
  };
}
```

`dotfiles.root` 必须是指向本地工作区的绝对路径**字符串**，不要使用会被复制到 Nix store 的路径表达式。模块通过 `mkOutOfStoreSymlink` 建立链接，最终指向可编辑工作区。

默认映射以模块源码为准，可按主机扩展或禁用：

```nix
{ lib, ... }:
{
  dotfiles.configLinks."my-app" = ".config/my-app";
  dotfiles.configLinks."another-app" = lib.mkForce null;
  dotfiles.homeLinks.".some-config" = ".some-config";
}
```

映射键是相对于 `xdg.configHome` 或 HOME 的目标路径，值是相对于 `dotfiles.root` 的来源路径。

### 公共原则

- **目录映射**适合独立配置目录，新增文件即可生效；保持 `recursive = false`，避免拆成逐文件链接。
- **文件映射**适合与 Home Manager 生成文件、插件或本地状态共享的目录。
- Pi 的旧映射默认链接 `settings.json`、`models.json`、`hud-footer.json` 和 `extensions`、`system-prompts`、`shepherdr` 三个目录。主机启用 `dotfiles.pi` 后，`settings.json` 改为本机普通文件，`models.json` 链接到所选 profile。两种模式都不管理 `pi-stamp.json`，因为 pi-stamp 0.53.0 拒绝将配置文件软链接；需要自定义时通过 `/stamp` 创建本机普通文件。
- 每个目标只保留一个配置所有者，避免软链接映射与 `programs.*` 同时生成同一文件。
- 本机特有配置优先使用软件原生的 include、配置片段或覆盖机制，独立于共享配置保存；确认加载顺序和优先级。
- 缓存、登录凭据、运行状态和安装产物不应作为公共配置同步。目录链接下的软件写入也会进入工作区，需要配合 `.gitignore` 和提交前审查。
- 密钥使用 sops-nix 加密管理，不将明文凭据提交到 dotfiles。

## Pi 模型 profile 和本机设置

`dotfiles/.pi/agent/settings.shared.json` 是公共基线；主题、工具、软件包等在这里维护。`dotfiles/.pi/agent/model-profiles/<profile>.json` 是完整的 Pi 模型目录，不是 Pi 会自动合并的片段。按模型和端点组合命名，新增或修改某个目录时，按需更新包含同一 provider 的其他 profile。

在主机的 Home Manager `user.nix` 中选择 profile 和启动模型，例如：

```nix
dotfiles.pi = {
  enable = true;
  modelProfile = "newapi";
  defaultProvider = "newapi";
  defaultModel = "gpt-6.1-sol";
  enabledModels = [ "newapi/**" ];
};
```

当前配置：`gkzhb-MBP` 使用 `magpie`，启动和轮换范围只包含 Magpie 模型；`devbox` 和 `zhb-nixos` 使用 `newapi`。`mixed` 同时包含两个供应商，目前没有主机选用。请确认目标机能访问 profile 中的端点并有对应凭据。`enabledModels` 为空表示不限制范围；非空时应包含默认模型，否则 Pi 可能选择范围内的其他模型。模型 profile 只控制 `models.json`，不影响共享扩展（例如 `magpie.ts`）自行注册的 provider。

**首次迁移**（以下 Shell 命令用 Bash 或 sh 执行）：

1. 停止 Pi 或退出会写设置的会话。在激活前备份两个 JSON 的**实际内容**；如果文件不存在，跳过该文件。不需要解除或重建其他 Pi 链接。

   ```sh
   backup="$(mktemp -d "$HOME/.pi-config-backup.XXXXXX")"
   chmod 700 "$backup"
   for f in settings.json models.json; do
     if [ -f "$HOME/.pi/agent/$f" ]; then
       cp -L "$HOME/.pi/agent/$f" "$backup/$f"
     fi
   done
   printf 'Pi backup: %s\n' "$backup"
   ```

2. 先提交/分发 **dotfiles 仓库**里的新基线和 profile，再更新目标机的 checkout（`just update-dotfiles`）。在 **nix-config 仓库**中，确保 `scripts/pi-sync-settings.py` 已被 Git 跟踪，flake 才能看到它。保留旧的 `settings.json`/`models.json` 源文件供尚未迁移的主机使用；不要继续在那里维护已迁移的配置。若目标原来是 Home Manager 管理的链接，直接激活即可；如果 `models.json` 是手工管理的普通文件或链接，先备份移走，避免目标冲突。
3. 使用对应的 `just build-darwin` / `just build-devbox` / `sudo just build-zhb` 激活新 Nix 配置，无需再手动同步。Home Manager 会先检查 JSON，确认旧 `settings.json` 链接是否属于上一代，再移除该链接并以旧内容为基础生成本机文件。已有普通文件会直接参与合并。若设置路径是手工链接，先备份实际内容，再把链接移开并用备份恢复为普通文件；激活会拒绝沿手工链接写入。
4. 验证 `test -f ~/.pi/agent/settings.json && test ! -L ~/.pi/agent/settings.json`、`realpath ~/.pi/agent/models.json`；在非项目目录新开 Pi 会话检查启动模型（恢复旧会话会使用会话记录中的模型）。

**日常同步**：每次 Home Manager **激活**都会自动同步；仅构建或 dry-run 不会写入。只改了公共基线时，也可以手动运行 `pi-sync-settings`，不必重建；修改主机默认值或 profile 后，重新激活即可。同步按「本机设置 → 公共基线 → 主机默认值」递归合并对象，同名数组整项替换；未被覆盖的本机字段保留。删除基线中的字段不会自动删除本机字段。Pi 的修改只写本机，下次激活或手动同步时会重新应用有声明的字段。不要在 Pi 正写设置时激活或同步。凭据、会话、已安装的包和扩展运行状态仍不纳入此同步。该机制只针对默认的 `~/.pi/agent`，不管理其他 `PI_CODING_AGENT_DIR`。

**回到旧映射**：备份移走本机普通 `settings.json`，然后禁用主机的 `dotfiles.pi` 并重新激活。不要把备份写回仍指向 checkout 的路径。

## Fish worktree 导航

- `tv-worktree`：用 Television 选择当前仓库 worktree，只改变当前 shell 目录。
- `tvn [仓库目录]`：默认当前仓库，用同一 picker 选择已有 worktree；按完整路径复用 tuios session，没有则创建。在 tuios 内切换客户端，在外部 attach，不改变当前 shell 目录，不创建/删除 Git worktree。
- `tvn.fish` 逐文件映射；辅助脚本随 `tuios` 整目录映射。新增映射需激活，临时使用可 `source dotfiles/.config/fish/functions/tvn.fish`（已有 Television/tuios 目录映射时）。

完整语义与隔离测试见 `dotfiles/.config/tuios/worktree-session.md`。

## 首次迁移与激活

1. 备份现有配置，比较差异，将需要保留的内容合并到 `dotfiles/`，不要盲目覆盖。
2. 将冲突的原文件或目录移到仓库外的备份位置；模块不会自动清理这些冲突。
3. 确认新增 Nix 文件已被外层 Git 跟踪，且所有映射来源存在。
4. 使用对应主机的构建入口激活，参见 [README](../README.md#building)。这些入口会构建并激活配置，不只是创建 dotfiles 链接。
5. 用 `realpath <配置路径>` 检查最终来源是否位于本地工作区。

迁移原路径后、激活之前，软件可能暂时无法读取配置，应缩短这一间隔并保留可恢复的备份。

`hud-footer.json` 已纳入映射。若 HOME 中仍是普通文件，激活前先比较它与 `dotfiles/.pi/agent/hud-footer.json`，将普通文件备份移走后再激活；模块不会强制覆盖。pi-hud-footer 0.8.0 支持经软链接读取和保存配置，菜单修改也会写入 dotfiles 工作区。

## zhb-nixos 首次迁移

这台主机使用 `hosts/zhb-nixos/user.nix`，通过 NixOS 集成 Home Manager；不要使用指向 VPS 配置的 `just build-home zhb`。日常激活入口为：

```sh
sudo just build-zhb
systemctl status home-manager-zhb.service
journalctl -u home-manager-zhb.service -b --no-pager
realpath ~/.config/nvim ~/.pi/agent/models.json
fish -ic 'functions cfg; functions dv'
```

只有 Home Manager 服务成功且软链接最终指向 `~/nix-config/dotfiles/`，才算链接迁移完成；同时确认 Pi 的本机 `settings.json` 是普通文件。首次激活会将冲突的普通文件或目录保留为同路径的 `*.before-home-manager`；如果备份已存在会拒绝覆盖，先检查并另行归档，不要直接删除。NixOS 构建或其他服务失败时也应检查 Home Manager 是否已运行，不要假定激活是事务性的。

迁移准备阶段保留 HOME 原路径不动，并在 `~/.local/state/dotfiles-migration/<时间>/` 保存选定配置及旧 `~/.dotfiles` 元数据的归档和清单。`dotfiles/` 从旧库本地克隆，origin 仍为 GitHub；本机的 Kitty 附加配置、Neovim lockfile、Yazi 插件及 Pi 本地扩展/提示词已复制到新工作区，并仅在 `.git/info/exclude` 中忽略。后续新增本地配置仍需遵守提交前审查原则。

CoC 在本机只映射 `coc/ultisnips`，安装扩展及运行状态继续留在 `~/.config/coc/`。Fish 仍按文件映射，本机 `*.local.fish`、`fish_variables` 和插件保持原位；Pi 的登录凭据、会话、npm 包、skills 及 `pi-stamp.json` 不迁移。

旧 `~/.dotfiles` 暂留作恢复，不要再用旧的 `git --git-dir=~/.dotfiles --work-tree=~` 工作流提交：它会把 Home Manager 链接误认为配置内容变更。激活后开启新 Fish，`cfg`/`dv` 会指向新工作区；激活前可显式使用 `git -C ~/nix-config/dotfiles`。

若要恢复旧方案，先从 NixOS 配置禁用本主机的 dotfiles 接入并重新激活，确认不再由 Home Manager 管理目标，再按清单逐一恢复对应备份；不要将归档直接解压覆盖仍被管理的链接，也不要仅回滚 NixOS generation 就认为所有 HOME 备份会自动还原。

## 日常维护与验证

已有映射中的配置内容可以直接在工作区或软件配置路径编辑，无需 Nix rebuild；软件是否需要 reload/restart 取决于其自身。新增映射或改变工作区路径后，需要重新激活。

```sh
git -C dotfiles status
git -C dotfiles diff
```

提交前确认没有敏感信息或无关运行数据。仅做模块求值验证、不激活系统：

```sh
nix eval --accept-flake-config --impure --json --file scripts/tests/test-dotfiles.nix
```
