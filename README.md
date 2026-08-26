# OpenIn

OpenIn adds a configurable Finder right-click menu and Finder toolbar button for opening the current directory in terminals, editors, or custom applications.

## Features

- Built-in Terminal and Editor list based on OpenInTerminal's supported applications.
- Built-in tty7 and Otty entries use their documented CLI launchers.
- Neovim opens through Kitty, following OpenInTerminal's supported command.
- Each item has separate checkboxes for Finder's contextual menu and toolbar dropdown.
- Custom applications can use a URL Scheme or Shell Command with `{path}`.
- Built-in applications expose their launch type (Shell Command or URL Scheme) and launch method, with per-item and reset-all controls.
- Shell commands are executed by the host app because Finder Sync extensions are sandboxed.

## Build

```bash
xcodebuild -project OpenIn.xcodeproj -scheme OpenIn -configuration Release -derivedDataPath build build
```

Launch `build/Build/Products/Release/OpenIn.app` once, then add OpenIn from Finder's **View → Customize Toolbar…**. If the extension is not visible, enable it in **System Settings → General → Login Items & Extensions**.

The settings window shows all supported apps. Installed apps are shown in both Finder menus by default; each menu can be disabled independently. Built-in launch types and launch methods can be edited and reset. Custom applications can use examples such as:

```text
myapp://open?path={path}
open -a Terminal {path}
```
