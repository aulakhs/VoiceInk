import Cocoa

final class MenuBarController {
    private var statusItem: NSStatusItem?
    private let appState: AppState
    var onQuit: (() -> Void)?

    init(appState: AppState) {
        self.appState = appState
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "VoiceInk")
        }

        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        let statusText: String
        switch appState.state {
        case .idle: statusText = "Ready"
        case .recording: statusText = "Recording..."
        case .transcribing: statusText = "Transcribing..."
        case .done: statusText = "Done"
        case .error: statusText = "Error"
        }

        let statusItem = NSMenuItem(title: "Status: \(statusText)", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        let hotkeyItem = NSMenuItem(title: "Hotkey: ⌥+A", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)

        menu.addItem(.separator())

        let autoTypeItem = NSMenuItem(
            title: "Auto-Type into Active Field",
            action: #selector(toggleAutoType),
            keyEquivalent: ""
        )
        autoTypeItem.target = self
        autoTypeItem.state = appState.autoTypeEnabled ? .on : .off
        menu.addItem(autoTypeItem)

        let smartModeItem = NSMenuItem(title: "Output Mode: \(OutputMode.smart.rawValue)", action: #selector(setSmartMode), keyEquivalent: "")
        smartModeItem.target = self
        smartModeItem.state = appState.outputMode == .smart ? .on : .off
        smartModeItem.isEnabled = appState.autoTypeEnabled
        menu.addItem(smartModeItem)

        let pasteModeItem = NSMenuItem(title: "Output Mode: \(OutputMode.paste.rawValue)", action: #selector(setPasteMode), keyEquivalent: "")
        pasteModeItem.target = self
        pasteModeItem.state = appState.outputMode == .paste ? .on : .off
        pasteModeItem.isEnabled = appState.autoTypeEnabled
        menu.addItem(pasteModeItem)

        let pasteEnterModeItem = NSMenuItem(title: "Output Mode: \(OutputMode.pasteAndEnter.rawValue)", action: #selector(setPasteAndEnterMode), keyEquivalent: "")
        pasteEnterModeItem.target = self
        pasteEnterModeItem.state = appState.outputMode == .pasteAndEnter ? .on : .off
        pasteEnterModeItem.isEnabled = appState.autoTypeEnabled
        menu.addItem(pasteEnterModeItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit VoiceInk", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem?.menu = menu
    }

    @objc private func toggleAutoType() {
        appState.autoTypeEnabled.toggle()
        rebuildMenu()
    }

    @objc private func setSmartMode() {
        appState.outputMode = .smart
        rebuildMenu()
    }

    @objc private func setPasteMode() {
        appState.outputMode = .paste
        rebuildMenu()
    }

    @objc private func setPasteAndEnterMode() {
        appState.outputMode = .pasteAndEnter
        rebuildMenu()
    }

    @objc private func quitApp() {
        onQuit?()
        NSApplication.shared.terminate(nil)
    }
}
