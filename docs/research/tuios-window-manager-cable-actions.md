# tuios window manager：Television cable actions 可行性

## 结论

可行。建议 cable actions 负责原生菜单和动作快捷键，`mode = "execute"` 调用 Python request 入口写入动作／选中 token；外层 `window-manager.py` 在 tv 退出后消费请求，继续现有目的地选择、校验、移动及关闭 popup 后跟随。

这不是 Ctrl+X 的模拟菜单；菜单由 Television 原生 action picker 提供，但业务行为继续集中在 Python。无需修改 Television 软件包或 Home Manager 映射。

## 当前调用链

- `dotfiles/.config/tuios/config.toml`：leader `ctrl+f`，`prefix+o` 调用窗口管理器。
- `dotfiles/.config/tuios/window-manager.py`：`Picker.choose` 生成 rows.tsv 和 entries.json，调用命名 channel 和显式 cable-dir。
- `dotfiles/.config/television/cable/tuios-windows.toml` / `tuios-destinations.toml`：只有 source、preview、UI，无 actions。
- 当前 Enter 返回 token 后由 Python 打开另一个 tv 操作列表，Alt+M/G/F 用 --expect 回传；所以 Ctrl+X 没有原生 actions 可展示。

## 建议用户交互

1. Ctrl+F → o 打开源 workspace 的窗口列表，搜索、上下键导航、Tab/Shift+Tab 多选。
2. Ctrl+X 或 Enter 打开原生 actions 菜单，按名称搜索或上下键选择，Enter 确认。
3. Move：选择目标 session/workspace，Enter 移动；完成后重新打开已更新的源列表。
4. Move and follow：选择目标，移动成功后写 intent 并结束 popup，外层校验并聚焦／切换原客户端。
5. Focus：仅允许一个窗口，写 intent 并结束 popup，再聚焦。多选时提示并拒绝，不进行任何聚焦操作。
6. Alt+M/G/F 绑定到相同 cable actions，跳过菜单。
7. 原生 action 菜单按 Ctrl+X 可返回窗口列表，不执行动作；Esc 返回行为在本地参考源码中同样存在，未在本轮 probe 单独断言。目的地 Esc 取消移动并返回窗口列表；窗口列表 Esc 关闭管理器。
8. Ctrl+R 可以保留原 --expect 刷新语义，不必一并改为原生 reload_source。

注意：execute 后 tv 已结束。普通移动后重新打开 tv，当前查询／多选默认重置，和原 Python 循环相近。目的地取消后若希望保留源查询和多选，需要另行设计状态恢复，不能承诺原生菜单自动保留跨进程状态。

## 推荐技术结构

```text
窗口 tv（cable actions）
  → execute Python --request ACTION TOKENS...
  → 校验 token 属于当前窗口 snapshot，原子写 request.json
  → 退出 tv
外层 Python manage
  → 消费并移除 request，恢复 snapshot 顺序，校验选中集合
  → 目的地 tv（普通单选 picker，无窗口 actions）
  → 原 move_windows / validate_* / check_client
  → 普通移动后刷新，或写 intent.json 并退出 popup
外层 launch
  → popup 关闭后 apply_intent
```

request.json 与 intent.json 不同：前者表示动作选择，后者表示 popup 退出后需要应用的聚焦／跟随。每次启动窗口 picker 前清理旧 request，使用原子写入，拒绝未知动作／token；不能将过期文件解释为新选择。窗口与目的地状态不应意外互相覆盖。

## 已验证的 Television 行为

安装版 `television 0.15.9`，测试只用临时 HOME/channel 和记录参数的 Python helper，无 tuios 命令。复验：

```sh
python3 .planning/probe-tv-native-actions.py
```

后台任务 bd13e381f exit 0，六项断言通过：

| 场景 | 结果 |
|---|---|
| Ctrl+X → Enter，execute 单选 | action helper 收到 move、w0；tv stdout 为空 |
| Tab 多选 → Ctrl+X → Enter | helper 收到 w0、w1，两项都保留 |
| Tab 多选 → Alt+M | 直接调用同一 action，收到两个 token |
| fork 菜单 action | helper 执行后 tv 保持运行，随后 Ctrl+C 退出 |
| Ctrl+X 打开 → Ctrl+X 返回 → Enter | 没有调用 helper，正常输出窗口 token |
| 使用简单 {} 而不是 token 模板 | helper 收到完整原始 token-tab-label，不是 source.output |

首次测试因 probe 生成 TOML 的 separator 转义错误失败；补充屏幕诊断后修正，非安装版或生产 channel 问题。

## 多选模板与安全

Action 模板接收 raw entry，并使用 set 集合，顺序不能作为业务依据；`source.output` 仅影响普通 picker 输出。复杂模板先按 separator 合并多行，所以简单 `{split:\t:0}` 不适合批量动作。

本轮验证的模板如下（split 分隔符中的换行与 Tab 为真实字符，使用 TOML 多行 literal string）：

```toml
[actions.move]
description = "Move to destination"
command = '''"$TWM_PYTHON" "$TWM_SCRIPT" --request move {split:
:..|map:{split:	:0}|join: }'''
mode = "execute"
separator = "\n"
```

这里仅生成 `w0 w1 ...` 安全 token；Python 再从 snapshot 查 UUID，按原列表顺序恢复并重做位置校验。不要把窗口名称／CWD／完整展示行通过 `{}` 放进 shell，也不要以 TV 多选集合顺序决定“跟随第一个窗口”。

## 键绑定与菜单限制

- 窗口 channel：Enter、Ctrl+X → toggle_action_picker；Alt+M/G/F → actions:move/move_follow/focus。
- 私有全局配置：Enter 保留 confirm_selection。ActionPicker 模式不使用 channel 级键绑定，避免 Enter 在菜单中反复切换。
- 原生动作列表固定，参考源码按动作名称排序。ActionSpec 没有按多选数动态隐藏字段；Focus 在多选时仍显示，应在 Python 拒绝。
- 目的地 channel 不添加上述动作，仅返回目标 token，显式禁用 Tab/backtab 多选是可选的交互改进。
- 不建议用同一个 destinations channel 再承载窗口动作菜单。

## 为什么不直接用 fork 执行业务

fork 支持挂起 tv、运行交互命令、再返回原 picker，适合普通移动。但业务还要求移动并跟随后自动关闭整个 popup。fork 的 action 结束时 tv 仍在，写 intent 本身不会让 popup 退出。需要额外退出信号、刷新源和多选清理，并为 focus/follow 使用不同模式；状态协调复杂。

全部用 execute 提交请求，统一交给现有 Python 循环，更容易保留当前安全语义。execute 的 action stdout 连接 TTY，不应作为外层选择协议；用私有临时 request 文件传递更稳妥。

## 实施范围与剩余验证

预计改动：窗口 cable、私有 tv 全局配置（显式 Ctrl+X）、window-manager.py 的 request 入口和窗口选择分支、单元／PTY 测试及 window-manager.md。目的地 cable、tuios 启动键和 Nix 映射原则上不变。

实施时需补充：原生菜单真实 Enter override、Focus 多选拒绝、目的地取消、过期 request/token、错误／部分失败、跟随后关闭 popup 的独立 daemon 集成测试。本轮仅证明 Television 动作模型可用，不证明改造后的全链已实现或测试完成。

## 参考

本机安装版 `tv --help` / `tv --version` 和以上真实 PTY 为版本行为依据。本地 `/Users/bytedance/gitrep/zhb/television` 为 0.15.6 + 5 commits，仅作结构参考：

- docs/reference/02-actions.md：action modes。
- docs/user-guide/01-channels.md：ActionSpec、separator、多选模板。
- docs/developers/release-notes/0.15.md：原生 Ctrl+X action picker。
- television/keymap.rs：ActionPicker 仅使用全局绑定。
- television/television.rs：原生菜单、选择集合与返回模式。
- television/utils/command.rs：raw entry 模板、TTY 输出和 execute/fork。
- television/app.rs：执行模式、菜单取消及执行后的处理。

未修改 dotfiles 运行配置、未提交、未调用 tuios 操作用户窗口。
