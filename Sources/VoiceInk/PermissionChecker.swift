import Cocoa
import AVFoundation

struct PermissionChecker {
    static func checkAccessibility() -> Bool {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        )
        return trusted
    }

    static func requestAccessibility() {
        // kAXTrustedCheckOptionPrompt: true tells macOS to show its own system prompt
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        log("Accessibility trusted: \(trusted)")
    }

    static func checkMicrophone() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static func requestMicrophone(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        case .denied, .restricted:
            showPermissionAlert(
                title: "Microphone Permission Required",
                message: "VoiceInk needs Microphone access to record your speech.\n\nPlease enable it in System Settings > Privacy & Security > Microphone.",
                settingsPane: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
            )
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    private static func showPermissionAlert(title: String, message: String, settingsPane: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: settingsPane) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
