import AppKit
import SwiftUI

private struct HiddenRowSeparator: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 13.0, *) {
            content.listRowSeparator(.hidden)
        } else {
            content
        }
    }
}

struct SettingsView: View {
    @State private var items = [MenuItemConfig]()
    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var showingResetAllAlert = false
    @State private var didLoadItems = false

    private var contextMenuCount: Int {
        items.filter(\.showInContextMenu).count
    }

    private var toolbarMenuCount: Int {
        items.filter(\.showInToolbarMenu).count
    }

    private var visibleItems: [MenuItemConfig] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(visibleItems.filter(\.isBuiltInApplication)) { item in
                        MenuItemRow(
                            item: item,
                            found: BuiltInApp.find(item.applicationID)?.isAvailable ?? false,
                            onUpdate: update,
                            onDelete: delete,
                            onReset: reset
                        )
                    }
                    ForEach(visibleItems.filter { !$0.isBuiltInApplication }) { item in
                        MenuItemRow(item: item, found: true, onUpdate: update, onDelete: delete, onReset: reset)
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text("Applications")
                        Text("\(toolbarMenuCount) toolbar · \(contextMenuCount) right-click")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search", text: $searchText)
                                .textFieldStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .frame(width: 180, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                    }
                }
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Application", systemImage: "plus")
                }
                .disabled(!didLoadItems)
                Button {
                    showingResetAllAlert = true
                } label: {
                    Label("Reset All", systemImage: "arrow.counterclockwise")
                }
                .disabled(!didLoadItems || !items.contains(where: { $0.isBuiltInApplication }))
                Spacer()
                Text("Toolbar above · right-click below")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
        .frame(minWidth: 520, minHeight: 420)
        .onAppear {
            didLoadItems = false
            items = []
            do {
                items = try MenuConfigStore.load()
                didLoadItems = true
            } catch {
                NSLog("[OpenIn] unable to load configuration: %@", error.localizedDescription)
            }
        }
        .onDisappear {
            if didLoadItems {
                MenuConfigStore.save(items)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddItemSheet { item in
                items.append(item)
                MenuConfigStore.save(items)
                showingAddSheet = false
            } onCancel: {
                showingAddSheet = false
            }
        }
        .alert("Reset all built-in applications?", isPresented: $showingResetAllAlert) {
            Button("Reset", role: .destructive) {
                resetAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This restores their type, launch method, and menu visibility to the defaults.")
        }
    }

    private func update(_ item: MenuItemConfig) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        MenuConfigStore.save(items)
    }

    private func delete(_ item: MenuItemConfig) {
        items.removeAll { $0.id == item.id }
        MenuConfigStore.save(items)
    }

    private func reset(_ item: MenuItemConfig) {
        guard let index = items.firstIndex(where: { $0.id == item.id }),
              let defaultItem = MenuConfigStore.defaultItem(for: item) else { return }
        items[index] = defaultItem
        MenuConfigStore.save(items)
    }

    private func resetAll() {
        items = MenuConfigStore.defaultItems() + items.filter { !$0.isBuiltInApplication }
        MenuConfigStore.save(items)
    }
}

struct MenuItemRow: View {
    let item: MenuItemConfig
    let found: Bool
    let onUpdate: (MenuItemConfig) -> Void
    let onDelete: (MenuItemConfig) -> Void
    let onReset: (MenuItemConfig) -> Void

    @State private var name: String
    @State private var actionType: MenuItemActionType
    @State private var template: String

    init(
        item: MenuItemConfig,
        found: Bool,
        onUpdate: @escaping (MenuItemConfig) -> Void,
        onDelete: @escaping (MenuItemConfig) -> Void,
        onReset: @escaping (MenuItemConfig) -> Void
    ) {
        self.item = item
        self.found = found
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onReset = onReset
        _name = State(initialValue: item.name)
        _actionType = State(initialValue: item.actionType)
        _template = State(initialValue: item.template)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { item.showInToolbarMenu },
                    set: { value in
                        var updated = item
                        updated.showInToolbarMenu = value
                        onUpdate(updated)
                    }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .frame(width: 22, height: 32)
                .help("Show in Finder toolbar menu")

                applicationIcon
                TextField("Display name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)

                Image(systemName: "rectangle.grid.1x2")
                    .font(.system(size: 16))
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                    .help("Type")
                    .accessibilityLabel("Type")
                Picker("", selection: $actionType) {
                    ForEach(MenuItemActionType.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .labelsHidden()
                .frame(width: 135)

                Spacer()
                if item.isBuiltInApplication {
                    Label(
                        found ? "Found" : "Not installed or not found",
                        systemImage: found ? "checkmark.circle.fill" : "questionmark.circle"
                    )
                        .labelStyle(.iconOnly)
                        .foregroundStyle(found ? .green : .orange)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                        .accessibilityLabel(found ? "Found" : "Not installed or not found")
                }
                if item.isBuiltInApplication {
                    if !item.isDefaultBuiltIn {
                        Button {
                            onReset(item)
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Reset to default")
                        .accessibilityLabel("Reset to default")
                    }
                } else {
                    Button {
                        onDelete(item)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }

            HStack(alignment: .center, spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { item.showInContextMenu },
                    set: { value in
                        var updated = item
                        updated.showInContextMenu = value
                        onUpdate(updated)
                    }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .frame(width: 22, height: 32)
                .help("Show in Finder right-click menu")

                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 20, weight: .light))
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.secondary)
                    .help("Launch")
                    .accessibilityLabel("Launch")
                TextField(
                    actionType == .urlScheme ? "myapp://open?path={path}" : "open -a Terminal {path}",
                    text: $template
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .modifier(HiddenRowSeparator())
        .onChange(of: name) { _ in commit() }
        .onChange(of: actionType) { _ in commit() }
        .onChange(of: template) { _ in commit() }
        .onChange(of: item) { updated in
            name = updated.name
            actionType = updated.actionType
            template = updated.template
        }
    }

    @ViewBuilder
    private var applicationIcon: some View {
        Group {
            if let path = applicationIconPath {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "macwindow")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 22, height: 22)
        .help("Application")
    }

    private var applicationIconPath: String? {
        guard let builtIn = BuiltInApp.find(item.applicationID) else { return nil }
        if let bundleIdentifier = builtIn.bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return url.path
        }

        guard let installationPath = builtIn.installationPath else { return nil }
        var url = URL(fileURLWithPath: installationPath)
        while url.path != "/" {
            if url.pathExtension == "app" {
                return url.path
            }
            url.deleteLastPathComponent()
        }
        return nil
    }

    private func commit() {
        onUpdate(MenuItemConfig(
            id: item.id,
            name: name,
            actionType: actionType,
            applicationID: item.applicationID,
            template: template,
            showInContextMenu: item.showInContextMenu,
            showInToolbarMenu: item.showInToolbarMenu
        ))
    }
}

struct AddItemSheet: View {
    @State private var name = ""
    @State private var actionType: MenuItemActionType = .shellCommand
    @State private var template = ""

    let onAdd: (MenuItemConfig) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Application")
                .font(.headline)

            TextField("Display name", text: $name)
                .textFieldStyle(.roundedBorder)

            Picker("Type", selection: $actionType) {
                Text("URL Scheme").tag(MenuItemActionType.urlScheme)
                Text("Shell Command").tag(MenuItemActionType.shellCommand)
            }

            TextField(
                actionType == .urlScheme ? "myapp://open?path={path}" : "open -a Terminal {path}",
                text: $template
            )
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))

            Text("{path} is replaced with the current Finder directory. Shell paths are safely quoted.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") {
                    onAdd(MenuItemConfig(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom Application" : name,
                        actionType: actionType,
                        template: template.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                }
                .keyboardShortcut(.return)
                .disabled(template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
