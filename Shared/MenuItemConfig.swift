import AppKit
import Foundation

enum MenuItemActionType: String, Codable, CaseIterable {
    case urlScheme = "URL Scheme"
    case shellCommand = "Shell Command"
}

enum AppCategory: String, Codable {
    case terminal = "Terminal"
    case editor = "Editor"
}

struct BuiltInApp: Identifiable, Equatable {
    let id: String
    let name: String
    let category: AppCategory
    let bundleIdentifier: String?
    let command: String
    let installationPath: String?

    init(
        id: String,
        name: String,
        category: AppCategory,
        bundleIdentifier: String?,
        command: String,
        installationPath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.bundleIdentifier = bundleIdentifier
        self.command = command
        self.installationPath = installationPath
    }

    var isAvailable: Bool {
        if id == "neovim" {
            return nvimPath != nil && BuiltInApp.find("kitty")?.isAvailable == true
        }
        let fileManager = FileManager.default
        if let installationPath {
            return fileManager.isExecutableFile(atPath: installationPath)
        }
        return applicationBundlePath != nil
    }

    var applicationBundlePath: String? {
        if let installationPath {
            var url = URL(fileURLWithPath: installationPath)
            while url.path != "/" {
                if url.pathExtension == "app" {
                    return url.path
                }
                url.deleteLastPathComponent()
            }
        }

        let fileManager = FileManager.default
        let homeApplications = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
        let candidates = [
            URL(fileURLWithPath: "/Applications/\(name).app"),
            homeApplications.appendingPathComponent("\(name).app"),
            URL(fileURLWithPath: "/System/Applications/\(name).app"),
            URL(fileURLWithPath: "/System/Applications/Utilities/\(name).app")
        ]
        return candidates.first { fileManager.fileExists(atPath: $0.path) }?.path
    }

    var resolvedCommand: String {
        guard id == "neovim", let nvimPath else { return command }
        return "open -na kitty --args \(nvimPath) {path}"
    }

    private var nvimPath: String? {
        let fileManager = FileManager.default
        return ["/opt/homebrew/bin/nvim", "/usr/local/bin/nvim"]
            .first { fileManager.isExecutableFile(atPath: $0) }
    }

    static let all: [BuiltInApp] = [
        .init(id: "terminal", name: "Terminal", category: .terminal, bundleIdentifier: "com.apple.Terminal", command: "open -a Terminal {path}"),
        .init(id: "iterm", name: "iTerm", category: .terminal, bundleIdentifier: "com.googlecode.iterm2", command: "open -a iTerm {path}"),
        .init(id: "hyper", name: "Hyper", category: .terminal, bundleIdentifier: "co.zeit.hyper", command: "open -a Hyper {path}"),
        .init(id: "alacritty", name: "Alacritty", category: .terminal, bundleIdentifier: "io.alacritty", command: "open -na Alacritty --args --working-directory {path}"),
        .init(id: "kitty", name: "kitty", category: .terminal, bundleIdentifier: "net.kovidgoyal.kitty", command: "open -na kitty --args --single-instance --instance-group 1 --directory {path}"),
        .init(id: "wezterm", name: "WezTerm", category: .terminal, bundleIdentifier: "com.github.wez.wezterm", command: "open -na wezterm --args start --cwd {path}"),
        .init(id: "rio", name: "Rio", category: .terminal, bundleIdentifier: nil, command: "/Applications/Rio.app/Contents/MacOS/rio --working-dir {path}", installationPath: "/Applications/Rio.app/Contents/MacOS/rio"),
        .init(id: "tabby", name: "Tabby", category: .terminal, bundleIdentifier: "org.tabby", command: "open -na tabby --args --directory {path}"),
        .init(id: "warp", name: "Warp", category: .terminal, bundleIdentifier: "dev.warp", command: "open -a Warp {path}"),
        .init(id: "cmux", name: "cmux", category: .terminal, bundleIdentifier: "com.cmuxterm.app", command: "open -a cmux {path}"),
        .init(id: "github-desktop", name: "GitHub Desktop", category: .terminal, bundleIdentifier: "com.github.GitHubClient", command: "open -a \"GitHub Desktop\" {path}"),
        .init(id: "gitkraken", name: "GitKraken", category: .terminal, bundleIdentifier: "com.axosoft.gitkraken", command: "open -na GitKraken --args --path {path}"),
        .init(id: "fork", name: "Fork", category: .terminal, bundleIdentifier: "com.DanPristupov.Fork", command: "open -a Fork {path}"),
        .init(id: "ghostty", name: "Ghostty", category: .terminal, bundleIdentifier: "com.mitchellh.ghostty", command: "open -a Ghostty {path}"),
        .init(id: "kaku", name: "Kaku", category: .terminal, bundleIdentifier: "fun.tw93.kaku", command: "open -a Kaku {path}"),
        .init(id: "tty7", name: "tty7", category: .terminal, bundleIdentifier: "com.github.tty7", command: "/Applications/tty7.app/Contents/MacOS/tty7 {path}", installationPath: "/Applications/tty7.app/Contents/MacOS/tty7"),
        .init(id: "otty", name: "Otty", category: .terminal, bundleIdentifier: nil, command: "/Applications/Otty.app/Contents/MacOS/otty-cli open {path}", installationPath: "/Applications/Otty.app/Contents/MacOS/otty-cli"),
        .init(id: "muxy", name: "Muxy", category: .terminal, bundleIdentifier: "com.muxy.app", command: "open -a Muxy {path}"),
        .init(id: "kooky", name: "kooky", category: .terminal, bundleIdentifier: "com.iamcorey.kooky", command: "\"$HOME/Library/Application Support/kooky/bin/kooky-cli\" open --cwd {path}", installationPath: NSHomeDirectory() + "/Library/Application Support/kooky/bin/kooky-cli"),
        .init(id: "herdr", name: "herdr", category: .terminal, bundleIdentifier: nil, command: "\"$HOME/.local/bin/herdr\" workspace create --cwd {path} --focus", installationPath: NSHomeDirectory() + "/.local/bin/herdr"),
        .init(id: "textedit", name: "TextEdit", category: .editor, bundleIdentifier: "com.apple.TextEdit", command: "open -a TextEdit {path}"),
        .init(id: "xcode", name: "Xcode", category: .editor, bundleIdentifier: "com.apple.dt.Xcode", command: "open -a Xcode {path}"),
        .init(id: "vscode", name: "Visual Studio Code", category: .editor, bundleIdentifier: "com.microsoft.VSCode", command: "open -a \"Visual Studio Code\" {path}"),
        .init(id: "atom", name: "Atom", category: .editor, bundleIdentifier: "com.github.atom", command: "open -a Atom {path}"),
        .init(id: "sublime", name: "Sublime Text", category: .editor, bundleIdentifier: "com.sublimetext.4", command: "open -a \"Sublime Text\" {path}"),
        .init(id: "vscodium", name: "VSCodium", category: .editor, bundleIdentifier: "com.visualstudio.code.oss", command: "open -a VSCodium {path}"),
        .init(id: "bbedit", name: "BBEdit", category: .editor, bundleIdentifier: "com.barebones.bbedit", command: "open -a BBEdit {path}"),
        .init(id: "vscode-insiders", name: "Visual Studio Code - Insiders", category: .editor, bundleIdentifier: "com.microsoft.VSCodeInsiders", command: "open -a \"Visual Studio Code - Insiders\" {path}"),
        .init(id: "textmate", name: "TextMate", category: .editor, bundleIdentifier: "com.macromates.TextMate", command: "open -a TextMate {path}"),
        .init(id: "coteditor", name: "CotEditor", category: .editor, bundleIdentifier: "com.coteditor.CotEditor", command: "open -a CotEditor {path}"),
        .init(id: "macvim", name: "MacVim", category: .editor, bundleIdentifier: "org.vim.MacVim", command: "open -a MacVim {path}"),
        .init(id: "typora", name: "Typora", category: .editor, bundleIdentifier: "abnerworks.Typora", command: "open -a Typora {path}"),
        .init(id: "nova", name: "Nova", category: .editor, bundleIdentifier: "com.panic.Nova", command: "open -a Nova {path}"),
        .init(id: "cursor", name: "Cursor", category: .editor, bundleIdentifier: "com.todesktop.230313mzl4w4u92", command: "open -a Cursor {path}"),
        .init(id: "zed", name: "Zed", category: .editor, bundleIdentifier: "dev.zed.Zed", command: "open -a Zed {path}"),
        .init(id: "emacs", name: "Emacs", category: .editor, bundleIdentifier: "org.gnu.Emacs", command: "open -a Emacs {path}"),
        .init(id: "appcode", name: "AppCode", category: .editor, bundleIdentifier: "com.jetbrains.AppCode", command: "open -a AppCode {path}"),
        .init(id: "clion", name: "CLion", category: .editor, bundleIdentifier: "com.jetbrains.CLion", command: "open -a CLion {path}"),
        .init(id: "fleet", name: "Fleet", category: .editor, bundleIdentifier: "com.jetbrains.fleet", command: "open -a Fleet {path}"),
        .init(id: "goland", name: "GoLand", category: .editor, bundleIdentifier: "com.jetbrains.goland", command: "open -a GoLand {path}"),
        .init(id: "intellij-idea", name: "IntelliJ IDEA", category: .editor, bundleIdentifier: "com.jetbrains.intellij", command: "open -a \"IntelliJ IDEA\" {path}"),
        .init(id: "phpstorm", name: "PhpStorm", category: .editor, bundleIdentifier: "com.jetbrains.PhpStorm", command: "open -a PhpStorm {path}"),
        .init(id: "pycharm", name: "PyCharm", category: .editor, bundleIdentifier: "com.jetbrains.pycharm", command: "open -a PyCharm {path}"),
        .init(id: "rubymine", name: "RubyMine", category: .editor, bundleIdentifier: "com.jetbrains.rubymine", command: "open -a RubyMine {path}"),
        .init(id: "webstorm", name: "WebStorm", category: .editor, bundleIdentifier: "com.jetbrains.webstorm", command: "open -a WebStorm {path}"),
        .init(id: "android-studio", name: "Android Studio", category: .editor, bundleIdentifier: "com.google.android.studio", command: "open -a \"Android Studio\" {path}"),
        .init(id: "neovim", name: "Neovim", category: .editor, bundleIdentifier: nil, command: "open -na kitty --args /opt/homebrew/bin/nvim {path}")
    ]

    static func find(_ id: String?) -> BuiltInApp? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}

struct MenuItemConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var actionType: MenuItemActionType
    var applicationID: String?
    var template: String
    var showInContextMenu: Bool
    var showInToolbarMenu: Bool

    init(
        id: UUID = UUID(),
        name: String,
        actionType: MenuItemActionType,
        applicationID: String? = nil,
        template: String,
        showInContextMenu: Bool = true,
        showInToolbarMenu: Bool = true
    ) {
        self.id = id
        self.name = name
        self.actionType = actionType
        self.applicationID = applicationID
        self.template = template
        self.showInContextMenu = showInContextMenu
        self.showInToolbarMenu = showInToolbarMenu
    }

    var isBuiltInApplication: Bool {
        applicationID != nil
    }

    var menuIdentifier: String {
        applicationID ?? id.uuidString
    }

    var isDefaultBuiltIn: Bool {
        guard let defaultItem = MenuConfigStore.defaultItem(for: self) else { return false }
        return name == defaultItem.name &&
               actionType == defaultItem.actionType &&
               template == defaultItem.template
    }
}

struct MenuConfigStore {
    static let extensionBundleID = "com.local.OpenIn.FinderSync"
    static let pathPlaceholder = "{path}"

    static let sharedDirectory: URL = {
        let base: URL
        if Bundle.main.bundleIdentifier == extensionBundleID {
            base = URL(fileURLWithPath: NSHomeDirectory())
        } else {
            base = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers/\(extensionBundleID)/Data")
        }
        let directory = base.appendingPathComponent("Library/Application Support/OpenIn")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            NSLog("[OpenIn] unable to create configuration directory: %@", error.localizedDescription)
        }
        return directory
    }()

    static let configFile = sharedDirectory.appendingPathComponent("menuitems.json")
    private static let shellRequestDirectory = sharedDirectory.appendingPathComponent("Shell Requests", isDirectory: true)

    private struct ShellRequest: Codable {
        let itemIdentifier: String
        let path: String
    }

    static func load() throws -> [MenuItemConfig] {
        guard FileManager.default.fileExists(atPath: configFile.path) else {
            return defaultItems()
        }
        let data = try Data(contentsOf: configFile)
        return try JSONDecoder().decode([MenuItemConfig].self, from: data)
    }

    static func bootstrapDefaultsIfNeeded() {
        guard Bundle.main.bundleIdentifier != extensionBundleID,
              !FileManager.default.fileExists(atPath: configFile.path) else {
            return
        }
        save(defaultItems())
    }

    static func save(_ items: [MenuItemConfig]) {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: configFile, options: .atomic)
        } catch {
            NSLog("[OpenIn] unable to save configuration: %@", error.localizedDescription)
        }
    }

    static func defaultItems() -> [MenuItemConfig] {
        BuiltInApp.all.map {
            MenuItemConfig(
                name: $0.name,
                actionType: .shellCommand,
                applicationID: $0.id,
                template: $0.resolvedCommand,
                showInContextMenu: $0.isAvailable,
                showInToolbarMenu: $0.isAvailable
            )
        }
    }

    static func defaultItem(for item: MenuItemConfig) -> MenuItemConfig? {
        guard let builtIn = BuiltInApp.find(item.applicationID) else { return nil }
        return MenuItemConfig(
            id: item.id,
            name: builtIn.name,
            actionType: .shellCommand,
            applicationID: builtIn.id,
            template: builtIn.resolvedCommand,
            showInContextMenu: item.showInContextMenu,
            showInToolbarMenu: item.showInToolbarMenu
        )
    }

    static func resolve(_ template: String, path: String) -> String {
        template.replacingOccurrences(of: pathPlaceholder, with: path)
    }

    static func urlEncodedPath(_ path: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~/")
        return path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
    }

    static func shellQuoted(_ path: String) -> String {
        "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    static func createShellRequest(itemIdentifier: String, path: String) -> String? {
        let requestID = UUID().uuidString
        let requestURL = shellRequestDirectory.appendingPathComponent(requestID).appendingPathExtension("json")
        do {
            try FileManager.default.createDirectory(at: shellRequestDirectory, withIntermediateDirectories: true)
            let request = ShellRequest(itemIdentifier: itemIdentifier, path: path)
            let data = try JSONEncoder().encode(request)
            try data.write(to: requestURL, options: .atomic)
            return requestID
        } catch {
            NSLog("[OpenIn] unable to create shell request: %@", error.localizedDescription)
            return nil
        }
    }

    static func consumeShellRequest(_ requestID: String) -> (itemIdentifier: String, path: String)? {
        guard UUID(uuidString: requestID) != nil else { return nil }
        let requestURL = shellRequestDirectory.appendingPathComponent(requestID).appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: requestURL) }
        guard let data = try? Data(contentsOf: requestURL),
              let request = try? JSONDecoder().decode(ShellRequest.self, from: data) else {
            return nil
        }
        return (request.itemIdentifier, request.path)
    }

    static func shellURL(for requestID: String) -> URL? {
        var components = URLComponents()
        components.scheme = "openin"
        components.host = "shell"
        components.queryItems = [URLQueryItem(name: "request", value: requestID)]
        return components.url
    }
}
