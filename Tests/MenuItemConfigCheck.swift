import AppKit
import Foundation

@main
struct MenuItemConfigCheck {
    static func main() throws {
        for menuKind in 0..<4 {
            for itemIndex in [0, 1, 999, 12_345] {
                let tag = FinderMenuTag.encode(menuKind: menuKind, itemIndex: itemIndex)
                let decoded = FinderMenuTag.decode(tag)!
                assert(decoded.menuKind == menuKind)
                assert(decoded.itemIndex == itemIndex)
            }
        }
        assert(FinderMenuTag.decode(-1) == nil)

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenIn Install Path Check \(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let app = root.appendingPathComponent("Found Apps/Rio.app", isDirectory: true)
        let executable = app.appendingPathComponent("Contents/MacOS/rio")
        try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        assert(BuiltInApp.find("rio")!.resolveInstallationPath(in: app.path) == executable.path)
        assert(BuiltInApp.find("terminal")!.resolvedInstallationPath == nil)
        assert(BuiltInApp.find("rio")!.bundleIdentifier == "com.raphaelamorim.rio")
        assert(BuiltInApp.find("otty")!.bundleIdentifier == "io.appmakes.otty")
        assert(BuiltInApp.find("sourcegit")!.bundleIdentifier == "com.sourcegit-scm.sourcegit")
        assert(BuiltInApp.find("alacritty")!.workspaceArguments(for: "/tmp/project", mode: .window) == ["--working-directory", "/tmp/project"])
        assert(BuiltInApp.find("wezterm")!.workspaceArguments(for: "/tmp/project", mode: .tab) == ["start", "--new-tab", "--cwd", "/tmp/project"])
        assert(BuiltInApp.find("smartgit")!.workspaceArguments(for: "/tmp/project", mode: .window) == ["--open", "/tmp/project"])
        assert(BuiltInApp.find("rio")!.workspaceArguments(for: "/tmp/project", mode: .window) == nil)
        let movedOttyApp = root.appendingPathComponent("User Apps/Otty.app", isDirectory: true)
        let movedOttyCLI = movedOttyApp.appendingPathComponent("Contents/MacOS/otty-cli")
        try FileManager.default.createDirectory(at: movedOttyCLI.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: movedOttyCLI)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: movedOttyCLI.path)
        assert(BuiltInApp.find("otty")!.resolveInstallationPath(in: movedOttyApp.path) == movedOttyCLI.path)
        let ottyCLI = root.appendingPathComponent("bin/otty")
        try FileManager.default.createDirectory(at: ottyCLI.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: ottyCLI)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: ottyCLI.path)
        assert(BuiltInApp.firstExecutable(in: ["/missing/otty", ottyCLI.path]) == ottyCLI.path)

        let resolvedCommand = MenuConfigStore.resolve(
            "{applicationPath} --working-dir {path}",
            path: MenuConfigStore.shellQuoted("/tmp/{applicationPath}"),
            applicationPath: "/tmp/Rio user's copy/rio"
        )
        assert(resolvedCommand == "'/tmp/Rio user'\\''s copy/rio' --working-dir '/tmp/{applicationPath}'")

        let shellRequests = root.appendingPathComponent("Shell Requests", isDirectory: true)
        let requestID = MenuConfigStore.createShellRequest(
            itemIdentifier: "otty",
            path: "/tmp/openin-test",
            in: shellRequests
        )!
        let pendingRequests = MenuConfigStore.consumePendingShellRequests(in: shellRequests)
        assert(pendingRequests.count == 1)
        assert(pendingRequests[0].itemIdentifier == "otty")
        assert(pendingRequests[0].path == "/tmp/openin-test")
        assert(MenuConfigStore.consumeShellRequest(requestID, in: shellRequests) == nil)

        let oldDefaults = [
            MenuItemConfig(name: "Rio", actionType: .shellCommand, applicationID: "rio", template: "/Applications/Rio.app/Contents/MacOS/rio --working-dir {path}"),
            MenuItemConfig(name: "tty7", actionType: .shellCommand, applicationID: "tty7", template: "/Applications/tty7.app/Contents/MacOS/tty7 {path}"),
            MenuItemConfig(name: "Otty", actionType: .shellCommand, applicationID: "otty", template: "/Applications/Otty.app/Contents/MacOS/otty-cli open {path}"),
            MenuItemConfig(name: "kitty", actionType: .shellCommand, applicationID: "kitty", template: "kitten @ launch --type=tab --cwd {path}", openMode: .tab)
        ]
        let customRio = MenuItemConfig(
            name: "My Rio",
            actionType: .shellCommand,
            applicationID: "rio",
            template: "custom-rio {path}"
        )
        let normalized = MenuConfigStore.normalizeBuiltInTemplates(oldDefaults + [customRio])
        for (index, item) in oldDefaults.enumerated() {
            assert(normalized[index].template == BuiltInApp.find(item.applicationID)!.command(for: .window))
        }
        assert(normalized[3].openMode == nil)
        assert(normalized[4].template == customRio.template)
        print("MenuItemConfig checks passed")
    }
}
