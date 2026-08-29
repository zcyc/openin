import Cocoa
import FinderSync

final class FinderSync: FIFinderSync {
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
        guard let items = try? MenuConfigStore.load() else { return nil }
        let visibleItems = items.filter {
            showsInToolbar ? $0.showInToolbarMenu : $0.showInContextMenu
        }
        let menu = NSMenu(title: "OpenIn")
        guard !visibleItems.isEmpty else { return nil }

        for item in visibleItems {
            let menuItem = NSMenuItem(
                title: item.name,
                action: #selector(menuItemAction(_:)),
                keyEquivalent: ""
            )
            menuItem.representedObject = item.id.uuidString
            menuItem.tag = menuKind == .contextualMenuForContainer ? 1 : 0
            menu.addItem(menuItem)
        }
        return menu
    }

    @IBAction func menuItemAction(_ sender: NSMenuItem) {
        guard let itemID = sender.representedObject as? String,
              let items = try? MenuConfigStore.load(),
              let item = items.first(where: { $0.id.uuidString == itemID }) else { return }
        let menuKind: FIMenuKind = sender.tag == 1 ? .contextualMenuForContainer : .contextualMenuForItems
        let path = currentPath(for: menuKind)

        switch item.actionType {
        case .shellCommand:
            let command = MenuConfigStore.resolve(item.template, path: MenuConfigStore.shellQuoted(path))
            guard let url = MenuConfigStore.shellURL(for: command) else { return }
            NSWorkspace.shared.open(url)
        case .urlScheme:
            let encodedPath = MenuConfigStore.urlEncodedPath(path)
            let resolved = MenuConfigStore.resolve(item.template, path: encodedPath)
            guard let url = URL(string: resolved) else {
                NSLog("[OpenIn] invalid URL Scheme template: %@", resolved)
                return
            }
            NSWorkspace.shared.open(url)
        }
    }

    private func currentPath(for menuKind: FIMenuKind) -> String {
        let controller = FIFinderSyncController.default()
        if menuKind == .contextualMenuForContainer,
           let targeted = controller.targetedURL() {
            return targeted.path
        }
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
