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
- Pi 默认链接 `settings.json`、`models.json`、`hud-footer.json` 和 `extensions`、`system-prompts`、`shepherdr` 三个目录；不管理 `pi-stamp.json`，因为 pi-stamp 0.53.0 拒绝配置文件软链接。需要自定义时通过 `/stamp` 创建本机普通文件。
- 每个目标只保留一个配置所有者，避免软链接映射与 `programs.*` 同时生成同一文件。
- 本机特有配置优先使用软件原生的 include、配置片段或覆盖机制，独立于共享配置保存；确认加载顺序和优先级。
- 缓存、登录凭据、运行状态和安装产物不应作为公共配置同步。目录链接下的软件写入也会进入工作区，需要配合 `.gitignore` 和提交前审查。
- 密钥使用 sops-nix 加密管理，不将明文凭据提交到 dotfiles。

## 首次迁移与激活

1. 备份现有配置，比较差异，将需要保留的内容合并到 `dotfiles/`，不要盲目覆盖。
2. 将冲突的原文件或目录移到仓库外的备份位置；模块不会自动清理这些冲突。
3. 确认新增 Nix 文件已被外层 Git 跟踪，且所有映射来源存在。
4. 使用对应主机的构建入口激活，参见 [README](../README.md#building)。这些入口会构建并激活配置，不只是创建 dotfiles 链接。
5. 用 `realpath <配置路径>` 检查最终来源是否位于本地工作区。

迁移原路径后、激活之前，软件可能暂时无法读取配置，应缩短这一间隔并保留可恢复的备份。

`hud-footer.json` 已纳入映射。若 HOME 中仍是普通文件，激活前先比较它与 `dotfiles/.pi/agent/hud-footer.json`，将普通文件备份移走后再激活；模块不会强制覆盖。pi-hud-footer 0.8.0 支持经软链接读取和保存配置，菜单修改也会写入 dotfiles 工作区。

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
