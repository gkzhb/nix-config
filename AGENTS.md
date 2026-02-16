## 项目介绍

当前项目是一个 nix flake 仓库，包括 nixos 配置和 user home-manager 配置。

当前 git 仓库被软链接到了 /etc/nixos 路径。

## 项目规范

经常使用的命令使用 just cli 来运行，配置见 .justfile 文件

构建 nixos 配置，使用命令 `just build-cn`

所有密钥配置，使用 sops-nix 来加密存储，运行时解密使用。
