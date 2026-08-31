import AppKit
import SwiftUI

let nimbusBlue = Color(red: 10 / 255, green: 132 / 255, blue: 1)
let nimbusNSBlue = NSColor(srgbRed: 10 / 255, green: 132 / 255, blue: 1, alpha: 1)

final class HUDModel: ObservableObject {
    @Published var running = false
    @Published var busy = false
    @Published var testing = false
    @Published var cancellingTest = false
    @Published var updating = false
    @Published var strategyName = "—"
    @Published var selectedStrategyID = ""
    @Published var strategies: [Strategy] = []
    @Published var ipsetMode = "none"
    @Published var loginEnabled = false
    @Published var versionTitle = "Версия"
    @Published var canInstallUpdate = false
    @Published var settingsOpen = false
    @Published var testTitle = "Тест стратегий"
    @Published var testEnabled = true

    var toggleService: () -> Void = {}
    var selectStrategy: (String) -> Void = { _ in }
    var selectIPSet: (String) -> Void = { _ in }
    var toggleLogin: () -> Void = {}
    var testStrategies: () -> Void = {}
    var openLists: () -> Void = {}
    var installUpdate: () -> Void = {}
    var quit: () -> Void = {}

    var ipsetTitle: String {
        switch ipsetMode {
        case "loaded": return "Стандартный"
        case "any": return "Все"
        default: return "Нет"
        }
    }

    var statusTitle: String { running ? "Включён" : "Выключен" }
    var switchCaption: String { running ? "Остановить" : "Запустить" }
}

final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class HUDController {
    private let model: HUDModel
    private let panel: HUDPanel
    private let hosting: NSHostingController<NimbusHUDView>
    private var monitor: Any?
    private var localMonitor: Any?
    private weak var statusButton: NSStatusBarButton?

    init(model: HUDModel) {
        self.model = model
        hosting = NSHostingController(rootView: NimbusHUDView(model: model))
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel = HUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 320),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isReleasedWhenClosed = false
        panel.contentViewController = hosting
    }

    var isVisible: Bool { panel.isVisible }

    func toggle(relativeTo button: NSStatusBarButton) {
        if panel.isVisible {
            close()
        } else {
            show(relativeTo: button)
        }
    }

    func show(relativeTo button: NSStatusBarButton) {
        statusButton = button
        hosting.view.layoutSubtreeIfNeeded()
        var size = hosting.view.fittingSize
        if size.width < 320 { size.width = 328 }
        if size.height < 200 { size.height = 280 }
        panel.setContentSize(size)

        guard let buttonWindow = button.window else { return }
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? buttonRect
        var x = buttonRect.midX - size.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        let y = buttonRect.minY - size.height - 6
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        panel.makeKeyAndOrderFront(nil)
        startMonitors()
    }

    func close() {
        stopMonitors()
        panel.orderOut(nil)
        model.settingsOpen = false
    }

    private func startMonitors() {
        stopMonitors()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closeIfOutside(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closeIfOutside(event)
            return event
        }
    }

    private func stopMonitors() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        monitor = nil
        localMonitor = nil
    }

    private func closeIfOutside(_ event: NSEvent) {
        guard panel.isVisible else { return }
        if event.window === panel { return }
        if event.window?.level == .popUpMenu { return }
        if let button = statusButton, event.window === button.window { return }
        let loc = NSEvent.mouseLocation
        if panel.frame.contains(loc) { return }
        if let button = statusButton, let window = button.window {
            let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
            if rect.contains(loc) { return }
        }
        close()
    }
}

struct NimbusHUDView: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        VStack(spacing: 0) {
            if model.settingsOpen {
                settingsPage
            } else {
                mainPage
            }
        }
        .padding(14)
        .frame(width: 328)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
        .padding(10)
    }

    private var mainPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Text("Движок zapret · стратегия \(model.strategyName)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            divider
            rowMenu(title: "Стратегия", value: model.strategyName) {
                ForEach(model.strategies, id: \.id) { strategy in
                    Button {
                        model.selectStrategy(strategy.id)
                    } label: {
                        if strategy.id == model.selectedStrategyID {
                            Label(strategy.name, systemImage: "checkmark")
                        } else {
                            Text(strategy.name)
                        }
                    }
                }
            }
            toggleRow(title: "Автозапуск", isOn: model.loginEnabled, action: model.toggleLogin)
            rowMenu(title: "Пресет", value: model.ipsetTitle) {
                presetButton("none", "Нет")
                presetButton("loaded", "Стандартный")
                presetButton("any", "Все")
            }
            divider
            HStack {
                Button {
                    model.settingsOpen = true
                } label: {
                    Label("Настройки", systemImage: "gearshape")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Spacer()
                Button("Выход", action: model.quit)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            .padding(.top, 2)
        }
    }

    private var settingsPage: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                model.settingsOpen = false
            } label: {
                Label("Назад", systemImage: "chevron.left")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)

            settingsRow(model.testTitle, enabled: model.testEnabled, action: model.testStrategies)
            settingsRow("Открыть списки", enabled: true, action: model.openLists)
            settingsRow(
                model.updating ? "Установка обновления…" : model.versionTitle,
                enabled: model.canInstallUpdate && !model.updating,
                action: model.installUpdate
            )
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(model.running ? nimbusBlue : Color.secondary.opacity(0.35))
                    .frame(width: 38, height: 38)
                Image(systemName: "cloud.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Nimbus")
                    .font(.headline)
                Text(model.statusTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(model.running ? nimbusBlue : Color.secondary)
            }
            Spacer()
            VStack(spacing: 4) {
                Toggle("", isOn: Binding(
                    get: { model.running },
                    set: { _ in model.toggleService() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(nimbusBlue)
                .labelsHidden()
                .disabled(model.busy)
                Text(model.switchCaption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func rowMenu<Content: View>(title: String, value: String, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .font(.subheadline)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .disabled(model.busy)
    }

    @ViewBuilder
    private func presetButton(_ id: String, _ title: String) -> some View {
        Button {
            model.selectIPSet(id)
        } label: {
            if model.ipsetMode == id {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private func toggleRow(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { _ in action() }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(nimbusBlue)
            .labelsHidden()
        }
        .padding(.vertical, 6)
    }

    private func settingsRow(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(enabled ? Color.primary : Color.secondary)
                Spacer()
            }
            .font(.subheadline)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 1)
            .padding(.vertical, 2)
    }
}
