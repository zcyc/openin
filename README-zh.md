# OpenIn

OpenIn 为 Finder 增加可配置的右键菜单和工具栏下拉按钮，可将当前目录打开到终端、编辑器或自定义应用中。

## 功能

- 内置 OpenInTerminal 的 Terminal、Editor 应用清单。
- 内置 tty7 和 Otty，使用它们公开的 CLI 打开当前目录。
- Neovim 通过 Kitty 启动，使用 OpenInTerminal 参考的命令。
- 每个项目分别用勾选框控制是否显示在 Finder 右键菜单和工具栏下拉菜单中。
- 支持添加自定义应用，可使用 URL Scheme 或 Shell Command，并用 `{path}` 代表当前目录。
- 内置应用可修改启动类型（Shell Command 或 URL Scheme）和 Launch，并支持单个重置或全部重置。
- Finder 扩展受沙盒限制，Shell Command 由宿主 App 安全转发执行。

## 编译

```bash
xcodebuild -project OpenIn.xcodeproj -scheme OpenIn -configuration Release -derivedDataPath build build
```

首次启动 `build/Build/Products/Release/OpenIn.app`，然后在 Finder 的“显示 → 自定义工具栏…”中加入 OpenIn。若看不到扩展，请在“系统设置 → 通用 → 登录项与扩展”中启用。

设置窗口会列出所有支持的应用，已安装的应用默认在两个菜单中勾选，也可以分别关闭。内置应用可修改类型和启动方式；自定义应用示例：

```text
myapp://open?path={path}
open -a Terminal {path}
```
