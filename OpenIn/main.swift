import Cocoa
import SwiftUI

let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var launchedViaURL = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if launchedViaURL {
            registerExtension()
            NSApp.terminate(nil)
            return
        }

        MenuConfigStore.bootstrapDefaultsIfNeeded()
        showSettingsWindow()
        registerExtension()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc private func handleGetURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        guard isFinderSyncRequest(event) else {
            NSLog("[OpenIn] rejected shell request from an untrusted sender")
            return
        }
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            return
        }
        handleShellURL(url)
    }

    private func isFinderSyncRequest(_ event: NSAppleEventDescriptor) -> Bool {
        guard let senderPID = event.attributeDescriptor(forKeyword: keySenderPIDAttr)?.int32Value,
              let sender = NSRunningApplication(processIdentifier: pid_t(senderPID)),
              sender.bundleIdentifier == MenuConfigStore.extensionBundleID,
              let senderURL = sender.bundleURL else {
            return false
        }

        let extensionURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("PlugIns")
            .appendingPathComponent("FinderSyncExtension.appex")
        return senderURL.standardizedFileURL == extensionURL.standardizedFileURL
    }

    private func handleShellURL(_ url: URL) {
        guard url.scheme == "openin",
              url.host == "shell",
              let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let requestID = queryItems.first(where: { $0.name == "request" })?.value,
              let request = MenuConfigStore.consumeShellRequest(requestID),
              let items = try? MenuConfigStore.load(),
              let item = items.first(where: { $0.menuIdentifier == request.itemIdentifier }),
              item.actionType == .shellCommand else {
            return
        }

        launchedViaURL = true
        let command = MenuConfigStore.resolve(item.template, path: MenuConfigStore.shellQuoted(request.path))
        executeShellCommand(command)
    }

    private func executeShellCommand(_ command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        do {
            try process.run()
        } catch {
            NSLog("[OpenIn] unable to execute shell command: %@", error.localizedDescription)
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
