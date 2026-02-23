import Foundation
import Combine

enum VoiceInkState: Equatable {
    case idle
    case recording
    case transcribing
    case done(String)
    case error(String)

    static func == (lhs: VoiceInkState, rhs: VoiceInkState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recording, .recording), (.transcribing, .transcribing):
            return true
        case (.done(let a), .done(let b)):
            return a == b
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

enum OutputMode: String {
    case smart = "Smart (Type short, paste long)"
    case paste = "Paste only"
    case pasteAndEnter = "Paste + Enter"
}

final class AppState: ObservableObject {
    @Published var state: VoiceInkState = .idle
    @Published var recordingDuration: TimeInterval = 0
    @Published var autoTypeEnabled: Bool = true
    @Published var outputMode: OutputMode = .paste

    private var recordingTimer: Timer?
    private var dismissTimer: Timer?

    func startRecording() {
        state = .recording
        recordingDuration = 0
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingDuration += 0.1
        }
    }

    func startTranscribing() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        state = .transcribing
    }

    func complete(text: String) {
        state = .done(text)
        scheduleDismiss(after: 1.5)
    }

    func fail(message: String) {
        state = .error(message)
        scheduleDismiss(after: 3.0)
    }

    func reset() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        dismissTimer?.invalidate()
        dismissTimer = nil
        state = .idle
        recordingDuration = 0
    }

    private func scheduleDismiss(after seconds: TimeInterval) {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.reset()
        }
    }
}
