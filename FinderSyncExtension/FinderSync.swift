import Cocoa
import FinderSync

final class FinderSync: FIFinderSync {
    private var cachedItems = [MenuItemConfig]()

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override var toolbarItemName: String {
        "OpenIn"
    }

    override var toolbarItemToolTip: String {
        "Open the current Finder directory with an application"
    }

    override var toolbarItemImage: NSImage {
        let configuration = NSImage.SymbolConfiguration(
            pointSize: 20,
            weight: .light,
            scale: .medium
        )
        if let symbol = NSImage(systemSymbolName: "arrow.up.forward.app", accessibilityDescription: "OpenIn")?.withSymbolConfiguration(configuration) {
            symbol.isTemplate = true
            return symbol
        }
        return NSImage(named: "ToolbarIcon")!
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .toolbarItemMenu ||
              menuKind == .contextualMenuForContainer ||
              menuKind == .contextualMenuForItems else {
            return nil
        }

        let showsInToolbar = menuKind == .toolbarItemMenu
        cachedItems = MenuConfigStore.load().filter {
            showsInToolbar ? $0.showInToolbarMenu : $0.showInContextMenu
        }
        let menu = NSMenu(title: "OpenIn")
        guard !cachedItems.isEmpty else { return nil }

        for (index, item) in cachedItems.enumerated() {
            let menuItem = NSMenuItem(
                title: item.name,
                action: #selector(menuItemAction(_:)),
                keyEquivalent: ""
            )
            menuItem.tag = index
            menu.addItem(menuItem)
        }
        return menu
    }

    @IBAction func menuItemAction(_ sender: NSMenuItem) {
        guard sender.tag >= 0, sender.tag < cachedItems.count else { return }
        let item = cachedItems[sender.tag]
        let path = currentPath()

        switch item.actionType {
        case .shellCommand:
            let command = MenuConfigStore.resolve(item.template, path: MenuConfigStore.shellQuoted(path))
            guard let url = MenuConfigStore.shellURL(for: command) else { return }
            NSWorkspace.shared.open(url)
        case .urlScheme:
            let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
            let resolved = MenuConfigStore.resolve(item.template, path: encodedPath)
            guard let url = URL(string: resolved) else {
                NSLog("[OpenIn] invalid URL Scheme template: %@", resolved)
                return
            }
            NSWorkspace.shared.open(url)
        }
    }

    private func currentPath() -> String {
        let controller = FIFinderSyncController.default()
        if let selected = controller.selectedItemURLs()?.first {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: selected.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return selected.path
            }
            return selected.deletingLastPathComponent().path
        }
        if let targeted = controller.targetedURL() {
            return targeted.path
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
            .path
    }

    override func beginObservingDirectory(at url: URL) {}
    override func endObservingDirectory(at url: URL) {}
    override func requestBadgeIdentifier(for url: URL) {}
}
