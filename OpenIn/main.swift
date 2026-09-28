import Cocoa
import SwiftUI

let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let pendingRequests = MenuConfigStore.consumePendingShellRequests()
        if !pendingRequests.isEmpty {
            NSLog("[OpenIn] processing %ld queued Finder request(s)", pendingRequests.count)
            let group = DispatchGroup()
            for request in pendingRequests {
                group.enter()
                handleShellRequest(request) { group.leave() }
            }
            group.notify(queue: .main) {
                NSApp.terminate(nil)
            }
            return
        }

        MenuConfigStore.bootstrapDefaultsIfNeeded()
        showSettingsWindow()
        registerExtension()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func handleShellRequest(
        _ request: (itemIdentifier: String, path: String),
        completion: @escaping () -> Void
    ) {
        guard let items = try? MenuConfigStore.load(),
              let item = items.first(where: { $0.menuIdentifier == request.itemIdentifier }),
              item.actionType == .shellCommand else {
            NSLog("[OpenIn] shell request has no matching command")
            completion()
            return
        }

        if let builtIn = BuiltInApp.find(item.applicationID) {
            let mode = item.openMode ?? .window
            let isBuiltInTemplate = item.name == builtIn.name &&
                item.template == builtIn.command(for: mode) &&
                !item.template.contains(MenuConfigStore.applicationPathPlaceholder)
            if isBuiltInTemplate && !["terminal", "iterm", "ghostty", "cmux"].contains(builtIn.id) {
                openBuiltIn(builtIn, item: item, path: request.path, mode: mode, completion: completion)
                return
            }
        }

        let applicationPath: String?
        if item.template.contains(MenuConfigStore.applicationPathPlaceholder) {
            guard let resolvedPath = BuiltInApp.find(item.applicationID)?.resolvedInstallationPath else {
                NSLog("[OpenIn] built-in application is unavailable: %@", item.applicationID ?? "unknown")
                completion()
                return
            }
            applicationPath = resolvedPath
        } else {
            applicationPath = nil
        }
        let command = MenuConfigStore.resolve(
            item.template,
            path: MenuConfigStore.shellQuoted(request.path),
            urlPath: MenuConfigStore.urlEncodedPath(request.path),
            applicationPath: applicationPath
        )
        executeShellCommand(
            applicationTargetedShellCommand(command, applicationID: item.applicationID),
            itemIdentifier: item.menuIdentifier
        )
        completion()
    }

    private func applicationTargetedShellCommand(_ command: String, applicationID: String?) -> String {
        let target: (name: String, bundleIdentifier: String)
        switch applicationID {
        case "terminal": target = ("Terminal", "com.apple.Terminal")
        case "iterm": target = ("iTerm2", "com.googlecode.iterm2")
        case "ghostty": target = ("Ghostty", "com.mitchellh.ghostty")
        default: return command
        }
        return command.replacingOccurrences(
            of: "application \"\(target.name)\"",
            with: "application id \"\(target.bundleIdentifier)\""
        )
    }

    private func openBuiltIn(
        _ builtIn: BuiltInApp,
        item: MenuItemConfig,
        path: String,
        mode: OpenMode,
        completion: @escaping () -> Void
    ) {
        guard let bundlePath = builtIn.applicationBundlePath else {
            NSLog("[OpenIn] application bundle is unavailable: %@ (%@)", builtIn.name, builtIn.bundleIdentifier ?? "no bundle ID")
            completion()
            return
        }

        let applicationURL = URL(fileURLWithPath: bundlePath)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        if builtIn.id == "warp" {
            let resolved = MenuConfigStore.resolve(
                item.template,
                path: path,
                urlPath: MenuConfigStore.urlEncodedPath(path)
            )
            guard let url = URL(string: resolved) else {
                NSLog("[OpenIn] invalid Warp URL: %@", resolved)
                completion()
                return
            }
            NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: configuration) { _, error in
                self.logOpenResult(error, application: builtIn.name)
                completion()
            }
            return
        }

        if let arguments = builtIn.workspaceArguments(for: path, mode: mode) {
            configuration.arguments = arguments
            configuration.createsNewApplicationInstance = builtIn.requiresNewInstanceForWorkspaceArguments
            NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { _, error in
                self.logOpenResult(error, application: builtIn.name)
                completion()
            }
            return
        }

        let targetURL = URL(fileURLWithPath: path, isDirectory: true)
        NSWorkspace.shared.open([targetURL], withApplicationAt: applicationURL, configuration: configuration) { _, error in
            self.logOpenResult(error, application: builtIn.name)
            completion()
        }
    }

    private func logOpenResult(_ error: Error?, application: String) {
        if let error {
            NSLog("[OpenIn] unable to open with %@: %@", application, error.localizedDescription)
        } else {
            NSLog("[OpenIn] opened with %@", application)
        }
    }

    private func executeShellCommand(_ command: String, itemIdentifier: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        var environment = ProcessInfo.processInfo.environment
        let inheritedPath = (environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
            .split(separator: ":")
            .map(String.init)
        // Finder-launched apps do not inherit paths configured only in shell startup files.
        environment["PATH"] = (inheritedPath + [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            NSHomeDirectory() + "/.local/bin"
        ])
            .joined(separator: ":")
        process.environment = environment
        process.terminationHandler = { process in
            NSLog(
                "[OpenIn] command for %@ exited with status %d",
                itemIdentifier,
                process.terminationStatus
            )
        }
        do {
            try process.run()
            NSLog("[OpenIn] launched command for %@", itemIdentifier)
        } catch {
            NSLog("[OpenIn] unable to execute command for %@: %@", itemIdentifier, error.localizedDescription)
        }
    }

    private func showSettingsWindow() {
        NSApp.setActivationPolicy(.regular)
        setupMainMenu()
        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "OpenIn Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 620, height: 620))
        window.minSize = NSSize(width: 520, height: 420)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About OpenIn", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit OpenIn", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z").keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = mainMenu
    }

    private func registerExtension() {
        let extensionURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("PlugIns")
            .appendingPathComponent("FinderSyncExtension.appex")
        guard FileManager.default.fileExists(atPath: extensionURL.path) else { return }

        let register = Process()
        register.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        register.arguments = ["-a", extensionURL.path]
        try? register.run()
        register.waitUntilExit()

        let enable = Process()
        enable.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        enable.arguments = ["-e", "use", "-i", MenuConfigStore.extensionBundleID]
        try? enable.run()
        enable.waitUntilExit()
    }
}
