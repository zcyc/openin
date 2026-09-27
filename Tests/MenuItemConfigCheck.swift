import AppKit
import Foundation

@main
struct MenuItemConfigCheck {
    static func main() throws {
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

        let resolvedCommand = MenuConfigStore.resolve(
            "{applicationPath} --working-dir {path}",
            path: MenuConfigStore.shellQuoted("/tmp/{applicationPath}"),
            applicationPath: "/tmp/Rio user's copy/rio"
        )
        assert(resolvedCommand == "'/tmp/Rio user'\\''s copy/rio' --working-dir '/tmp/{applicationPath}'")

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
