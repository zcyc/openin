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
        let visibleItems = items.filter { $0.isVisible(inToolbarMenu: showsInToolbar) }
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
            menuItem.tag = FinderMenuTag.encode(menuKind: menuKindTag, itemIndex: index)
            menu.addItem(menuItem)
        }
        return menu
    }

    @IBAction func menuItemAction(_ sender: NSMenuItem) {
        guard let selection = FinderMenuTag.decode(sender.tag) else {
            NSLog("[OpenIn] Finder menu action has an invalid tag: %ld", sender.tag)
            return
        }
        NSLog("[OpenIn] Finder menu action received (tag: %ld)", sender.tag)
        let menuKind: FIMenuKind
        switch selection.menuKind {
        case 1: menuKind = .contextualMenuForContainer
        case 2: menuKind = .contextualMenuForSidebar
        case 3: menuKind = .toolbarItemMenu
        case 0: menuKind = .contextualMenuForItems
        default: return
        }
        guard let items = try? MenuConfigStore.load() else {
            NSLog("[OpenIn] unable to load menu configuration")
            return
        }
        let visibleItems = items.filter { $0.isVisible(inToolbarMenu: menuKind == .toolbarItemMenu) }
        guard visibleItems.indices.contains(selection.itemIndex) else {
            NSLog("[OpenIn] Finder menu item index is no longer available: %ld", selection.itemIndex)
            return
        }
        let item = visibleItems[selection.itemIndex]
        guard let path = currentPath(for: menuKind) else {
            NSLog("[OpenIn] Finder did not provide a target path (tag: %ld)", sender.tag)
            return
        }

        switch item.actionType {
        case .shellCommand:
            guard let requestID = MenuConfigStore.createShellRequest(itemIdentifier: item.menuIdentifier, path: path) else { return }
            let applicationURL = Bundle.main.bundleURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { _, error in
                if let error {
                    _ = MenuConfigStore.consumeShellRequest(requestID)
                    NSLog("[OpenIn] unable to dispatch shell request for %@: %@", item.menuIdentifier, error.localizedDescription)
                } else {
                    NSLog("[OpenIn] launched shell request helper for %@", item.menuIdentifier)
                }
            }
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

    private func currentPath(for menuKind: FIMenuKind) -> String? {
        let controller = FIFinderSyncController.default()
        if (menuKind == .contextualMenuForContainer || menuKind == .contextualMenuForSidebar),
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
        return nil
    }

    override func beginObservingDirectory(at url: URL) {}
    override func endObservingDirectory(at url: URL) {}
    override func requestBadgeIdentifier(for url: URL) {}
}
