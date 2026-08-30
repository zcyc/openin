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
              menuKind == .contextualMenuForItems ||
              menuKind == .contextualMenuForSidebar else {
            return nil
        }

        let showsInToolbar = menuKind == .toolbarItemMenu
        guard let items = try? MenuConfigStore.load() else { return nil }
        let visibleItems = items.filter {
            showsInToolbar ? $0.showInToolbarMenu : $0.showInContextMenu
        }
        let menu = NSMenu(title: "OpenIn")
        guard !visibleItems.isEmpty else { return nil }

        let menuKindTag: Int
        switch menuKind {
        case .contextualMenuForContainer: menuKindTag = 1
        case .contextualMenuForSidebar: menuKindTag = 2
        case .toolbarItemMenu: menuKindTag = 3
        default: menuKindTag = 0
        }

        for (index, item) in visibleItems.enumerated() {
            let menuItem = NSMenuItem(
                title: item.name,
                action: #selector(menuItemAction(_:)),
                keyEquivalent: ""
            )
            menuItem.tag = menuKindTag * 1000 + index
            menu.addItem(menuItem)
        }
        return menu
    }

    @IBAction func menuItemAction(_ sender: NSMenuItem) {
        let menuIndex = sender.tag % 1000
        let menuKind: FIMenuKind
        switch sender.tag / 1000 {
        case 1: menuKind = .contextualMenuForContainer
        case 2: menuKind = .contextualMenuForSidebar
        case 3: menuKind = .toolbarItemMenu
        case 0: menuKind = .contextualMenuForItems
        default: return
        }
        guard let items = try? MenuConfigStore.load() else { return }
        let visibleItems = items.filter {
            menuKind == .toolbarItemMenu ? $0.showInToolbarMenu : $0.showInContextMenu
        }
        guard visibleItems.indices.contains(menuIndex) else { return }
        let item = visibleItems[menuIndex]
        let path = currentPath(for: menuKind)

        switch item.actionType {
        case .shellCommand:
            guard let requestID = MenuConfigStore.createShellRequest(itemIdentifier: item.menuIdentifier, path: path),
                  let url = MenuConfigStore.shellURL(for: requestID) else { return }
            guard NSWorkspace.shared.open(url) else {
                NSLog("[OpenIn] unable to open shell request URL for %@", item.menuIdentifier)
                return
            }
            NSLog("[OpenIn] dispatched shell request for %@", item.menuIdentifier)
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
