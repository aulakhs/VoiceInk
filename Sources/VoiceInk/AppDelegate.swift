import Cocoa
import Combine

private let logURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("voiceink-debug.log")

func log(_ message: String) {
    let line = "[VoiceInk] \(message)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logURL.path) {
            if let fh = try? FileHandle(forWritingTo: logURL) {
                fh.seekToEndOfFile()
                fh.write(data)
                fh.closeFile()
            }
        } else {
            try? data.write(to: logURL)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    private let hotkeyManager = HotkeyManager()
    private let recorder = AudioRecorder()
    private let transcriptionService = TranscriptionService()
    private let textOutput = TextOutputService()
    private var menuBar: MenuBarController!
    private var pillWindow: FloatingPillWindow!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("=== App launched ===")
        
        // Check permissions
        PermissionChecker.requestAccessibility()
        PermissionChecker.requestMicrophone { granted in
            log("Microphone permission: \(granted)")
        }

        // Start setup immediately — don't gate on async callback
        finishSetup()
    }

    private func finishSetup() {
        // Menu bar
        menuBar = MenuBarController(appState: appState)
        menuBar.setup()
        menuBar.onQuit = { [weak self] in
            self?.hotkeyManager.stop()
        }

        // Floating pill
        pillWindow = FloatingPillWindow(appState: appState)

        // Watch state changes to show/hide pill and update menu
        appState.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)

        // Hotkey
        hotkeyManager.onHotkey = { [weak self] in
            self?.handleHotkey()
        }
        hotkeyManager.start()

        log("Ready — press Option+A to start recording")
        
        // Show notification that app is running
        let notification = NSUserNotification()
        notification.title = "VoiceInk is Ready"
        notification.informativeText = "Press ⌥+A to start recording"
        notification.soundName = nil
        NSUserNotificationCenter.default.deliver(notification)
    }

    private func handleHotkey() {
        NSSound.beep()  // Audio feedback
        log("Hotkey triggered! State: \(appState.state)")
        
        // Force show pill for testing
        pillWindow.showPill()
        
        switch appState.state {
        case .idle:
            log("Starting recording...")
            startRecording()
        case .recording:
            log("Stopping recording...")
            stopAndTranscribe()
        case .transcribing, .done, .error:
            // Ignore during these states
            log("Ignoring hotkey in state: \(appState.state)")
            break
        }
    }

    private func startRecording() {
        guard PermissionChecker.checkMicrophone() else {
            PermissionChecker.requestMicrophone { _ in }
            return
        }

        do {
            _ = try recorder.startRecording()
            appState.startRecording()
        } catch let error as AudioRecorder.RecorderError where error == .noMicrophone {
            log("Recording error: \(error.localizedDescription)")
            appState.fail(message: "No mic found")
        } catch {
            log("Recording error: \(error.localizedDescription)")
            appState.fail(message: "Mic error")
        }
    }

    private func stopAndTranscribe() {
        guard let audioURL = recorder.stopRecording() else {
            appState.fail(message: "No audio recorded")
            return
        }

        appState.startTranscribing()
        log("Transcribing audio: \(audioURL.path)")

        Task {
            do {
                let text = try await transcriptionService.transcribe(audioURL: audioURL)
                await MainActor.run {
                    log("Transcription result: \(text.prefix(80))")
                    textOutput.copyToClipboard(text)
                    if appState.autoTypeEnabled {
                        textOutput.output(text: text, mode: appState.outputMode)
                    }
                    appState.complete(text: text)
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: audioURL)
                }
            } catch {
                await MainActor.run {
                    log("Transcription error: \(error.localizedDescription)")
                    appState.fail(message: "Transcription failed")
                    try? FileManager.default.removeItem(at: audioURL)
                }
            }
        }
    }

    private func handleStateChange(_ state: VoiceInkState) {
        menuBar.rebuildMenu()

        switch state {
        case .idle:
            pillWindow.hidePill()
        case .recording, .transcribing, .done, .error:
            pillWindow.showPill()
        }
    }
}
