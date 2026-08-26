# tty7 / Otty 用法研究

研究范围：仅依据项目官方 README、官方文档、官方源码/构建脚本；无法由一手资料确认的内容单独标注。

## 结论

| 应用 | 已确认的 Bundle ID | 已确认的可执行文件 | 打开目录的官方用法 | 对用户示例的判断 |
|---|---|---|---|---|
| tty7 | `com.github.tty7` | GUI：`/Applications/tty7.app/Contents/MacOS/tty7-app`；CLI：`/Applications/tty7.app/Contents/MacOS/tty7` | `tty7 [PATH]` | `/Applications/tty7.app/Contents/MacOS/tty7-app tty7 PATH` **不符合官方 CLI 语法**；优先使用 `/Applications/tty7.app/Contents/MacOS/tty7 PATH` |
| Otty | 官方资料中未发现 | 官方文档只说明 CLI 随 App 分发；固定内部路径未在官方文档中声明 | `otty open [path]` | `/Applications/Otty.app/Contents/MacOS/otty-cli open PATH` 的 `open PATH` 参数正确；内部路径由官方资料无法独立确认 |

## tty7

- 官方 CLI 参考明确写出 `tty7 [PATH]`：无子命令时，已有窗口会打开指定路径的新 tab；没有窗口时启动 App。没有 `PATH` 时只激活 App。
- 官方 macOS 打包脚本把 GUI 二进制复制为 `Contents/MacOS/tty7-app`，把 CLI 复制为 `Contents/MacOS/tty7`，并在 `Info.plist` 中声明 `CFBundleIdentifier` 为 `com.github.tty7`。
- 因此，给 OpenIn 配置时应把 `tty7` 作为 Shell Command，模板为：

  ```sh
  /Applications/tty7.app/Contents/MacOS/tty7 {path}
  ```

- 用户给出的 `tty7-app tty7 PATH` 同时混用了 GUI 可执行文件名和 CLI 的命令名；官方资料没有把 `tty7-app tty7 PATH` 作为受支持调用方式。

来源：

- [tty7 官方 CLI 参考](https://github.com/l0ng-ai/tty7/blob/main/docs/cli/reference.mdx#L226-L232)
- [tty7 官方 README（macOS 安装与内置 CLI）](https://github.com/l0ng-ai/tty7/blob/main/README.md#L29-L46)
- [tty7 官方 macOS 打包脚本（GUI、CLI 路径及 Bundle ID）](https://github.com/l0ng-ai/tty7/blob/main/.github/scripts/bundle-macos.sh#L29-L39)
- [tty7 官方 macOS 打包脚本（Bundle ID）](https://github.com/l0ng-ai/tty7/blob/main/.github/scripts/bundle-macos.sh#L56-L68)

## Otty

- Otty 官方 CLI 参考明确记录：`otty open [path]` 打开新窗口；示例为 `otty open ./projects`。官方 CLI 使用文档还说明相对路径按当前目录解析，并且 `otty open` 在 App 未运行时会启动 App。
- Otty 官方使用文档说明 CLI 随 App 提供，用户可通过 Settings → Shell → Install CLI 安装到 `/usr/local/bin/otty`。这确认了 CLI 的公开入口和参数，但没有确认 App 内部二进制的绝对路径。
- 在公开的 Otty 官方 README、CLI 文档和 GitHub 源码入口中，没有发现 `CFBundleIdentifier`、`Contents/MacOS/otty-cli` 或 macOS `Info.plist` 的一手声明。因此不能把 `com.*` Bundle ID 或该内部路径写成已确认事实。
- 一个独立的第三方 Otty 集成项目把 `/Applications/Otty.app/Contents/MacOS/otty-cli` 作为 macOS 默认路径；这能说明该路径有现实使用依据，但不是 Otty 官方来源。若允许采用该外部证据，用户示例可写为：

  ```sh
  /Applications/Otty.app/Contents/MacOS/otty-cli open {path}
  ```

  其可靠性低于官方安装后的 `/usr/local/bin/otty open {path}`。对 OpenIn 而言，若目标是“一定存在的链接”，应优先使用：

  ```sh
  /usr/local/bin/otty open {path}
  ```

  前提是用户已在 Otty 设置中安装 CLI；否则该路径也不能保证存在。

来源：

- [Otty 官方 CLI 参考：`otty open [path]`](https://docs.otty.sh/reference/cli#otty-open-path--open-a-new-window)
- [Otty 官方 CLI 使用说明：CLI 随 App、安装到 `/usr/local/bin/otty`、路径参数](https://docs.otty.sh/workflows/cli-usage#install-the-cli)
- [Otty 官方 README：macOS 发布包](https://github.com/otty-shell/otty#install)
- [第三方 pi-otty 集成：`otty-cli` 默认路径（非 Otty 官方来源）](https://github.com/killpanda/pi-otty#configuration)

## 对后续实现的建议

本次不修改源码，也不添加应用。若后续实现，tty7 可直接加入官方确认的 CLI 模板；Otty 应在设置中作为可选 Shell Command，优先使用用户已安装的 `otty` PATH 命令，或明确标注 `/Applications/Otty.app/Contents/MacOS/otty-cli` 是基于第三方集成验证而非 Otty 官方声明。
