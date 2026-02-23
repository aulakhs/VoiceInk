import Cocoa
import Carbon.HIToolbox

final class TextOutputService {
    func output(text: String, mode: OutputMode) {
        copyToClipboard(text)

        switch mode {
        case .smart:
            if text.count < 200 {
                typeText(text)
            } else {
                simulatePaste()
            }
        case .paste:
            simulatePaste()
        case .pasteAndEnter:
            simulatePaste()
            usleep(40_000)
            pressEnter()
        }
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func typeText(_ text: String) {
        // Type in chunks of 20 characters via CGEvent unicode injection
        let chunks = stride(from: 0, to: text.count, by: 20).map { start -> String in
            let startIdx = text.index(text.startIndex, offsetBy: start)
            let endIdx = text.index(startIdx, offsetBy: min(20, text.count - start))
            return String(text[startIdx..<endIdx])
        }

        for chunk in chunks {
            let chars = Array(chunk.utf16)
            for char in chars {
                var unichar = char
                if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
                    keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unichar)
                    keyDown.post(tap: .cghidEventTap)
                }
                if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
                    keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unichar)
                    keyUp.post(tap: .cghidEventTap)
                }
            }
            // Small delay between chunks to let apps process
            usleep(10_000) // 10ms
        }
    }

    private func simulatePaste() {
        // Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode = CGKeyCode(kVK_ANSI_V)

        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }
    }

    private func pressEnter() {
        let source = CGEventSource(stateID: .hidSystemState)
        let returnKey = CGKeyCode(kVK_Return)

        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: returnKey, keyDown: true) {
            keyDown.post(tap: .cghidEventTap)
        }
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: returnKey, keyDown: false) {
            keyUp.post(tap: .cghidEventTap)
        }
    }
}
