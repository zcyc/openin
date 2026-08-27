# OpenIn

OpenIn 为 Finder 增加可配置的右键菜单和工具栏下拉按钮，可将当前目录打开到终端、编辑器或自定义应用中。

<p align="center">
  <img src="assets/openin_app_icon.png" alt="OpenIn 应用图标" width="128">
</p>

## 功能

- 内置 OpenInTerminal 的 Terminal、Editor 应用清单。
- 额外内置 tty7、Otty、Muxy、kooky、herdr 和 Rio。
- Neovim 通过 Kitty 启动，使用 OpenInTerminal 参考的命令。
- 每个项目分别用勾选框控制是否显示在 Finder 右键菜单和工具栏下拉菜单中。
- 支持添加自定义应用，可使用 URL Scheme 或 Shell Command，并用 `{path}` 代表当前目录。
- 内置应用可修改启动类型（Shell Command 或 URL Scheme）和 Launch，并支持单个重置或全部重置。
- Finder 扩展受沙盒限制，Shell Command 由宿主 App 安全转发执行。

## 截图

<p align="center">
  <img src="assets/openin-settings.png" alt="OpenIn 设置窗口" width="720">
</p>

## 系统自带功能与 OpenIn 的边界

OpenIn 不内置终端、编辑器或文件管理器，也不替代 Finder 的原生功能。它只是将电脑中已经安装的应用启动方式集中到 Finder 的一级菜单中。以下功能可以直接使用 macOS 的原生入口：

- **复制路径**——选中项目后按 **⌥⌘C**；按住 **⌥** 再打开右键菜单，也会显示“将……拷贝为路径名称”。
- **在终端中打开**——在“系统设置 → 键盘 → 键盘快捷键 → 服务 → 文件和文件夹”中启用的“在文件夹中新建终端”；
- **在编辑器中打开**——Finder 的“打开方式”可以直接使用 Visual Studio Code、Cursor 等支持文件夹的应用，不需要 shell integration。
- **新建文件**——macOS 目前没有 Finder 原生的“新建文件”命令，OpenIn 也不提供此功能。需要时可以在终端执行 `touch filename.ext`。

## 编译并安装（免费本地自签名）

仓库中的 [Makefile](Makefile) 已封装编译、签名、注册扩展和重启 Finder 流程：

```bash
make install  # 编译、签名、安装并启用 Finder 扩展
```

如果无法写入 `/Applications`，可以执行 `make install INSTALL_DIR="$HOME/Applications"`，或在 Finder 中把 `build/manual/Release/OpenIn.app` 拖入 Applications。

设置窗口会列出所有支持的应用，已安装的应用默认在两个菜单中勾选，也可以分别关闭。内置应用可修改类型和启动方式；自定义应用示例：

```text
myapp://open?path={path}
open -a Terminal {path}
```

## 许可证

[GNU Affero General Public License v3.0 或更高版本](LICENSE)
