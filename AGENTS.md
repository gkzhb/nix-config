## 项目介绍

当前项目是一个 nix flake 仓库，包括多个主机的配置。


## 项目规范

经常使用的命令使用 just cli 来运行，配置见 .justfile 文件

例如构建 nixos 配置，使用命令 `just build`

所有密钥配置，使用 sops-nix 来加密存储，运行时解密使用。

## 关于 nix 配置选项

使用 optnix cli 工具来获取当前系统的各个 nix 工具的配置项。

## Hosts

### home-nixos

在 home-nixos 上，此 git 仓库被软链接到了 /etc/nixos 路径。

可使用 `just build` 来构建

### devbox

在 devbox 上，此仓库被软链接到 `$HOME/.config/system-manager`

使用 system-manager 管理安装系统包，使用 `just build-devbox` 来构建 system-manager 配置。

使用 standalone home-manager 管理用户包，使用 `just build-home zhanghaibin.zhb` 构建 home-manager 配置。

### gkzhb-MBP

在 gkzhb-MBP 上使用 nix-darwin ，此仓库被软链到 `/etc/nix-darwin`，使用 `just build-darwin` 来构建 nix-darwin。

构建 nix-darwin 的同时也会更新构建 home-manager。
