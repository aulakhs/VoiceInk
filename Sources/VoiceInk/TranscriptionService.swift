import Foundation

final class TranscriptionService {
    private let pythonPath: String
    private let scriptPath: String

    init(
        pythonPath: String = NSString(string: "~/.openclaw/parakeet-env/bin/python3").expandingTildeInPath,
        scriptPath: String = NSString(string: "~/.openclaw/scripts/transcribe.py").expandingTildeInPath
    ) {
        self.pythonPath = pythonPath
        self.scriptPath = scriptPath
    }

    func transcribe(audioURL: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [pythonPath, scriptPath] in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: pythonPath)
                process.arguments = [scriptPath, audioURL.path, "--json"]

                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr

                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    continuation.resume(throwing: TranscriptionError.processLaunchFailed(error.localizedDescription))
                    return
                }

                guard process.terminationStatus == 0 else {
                    let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                    let errStr = String(data: errData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: TranscriptionError.processExitFailure(Int(process.terminationStatus), errStr))
                    return
                }

                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                guard let outStr = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !outStr.isEmpty else {
                    continuation.resume(throwing: TranscriptionError.emptyOutput)
                    return
                }

                // Try JSON parse first
                if let jsonData = outStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let text = json["text"] as? String {
                    continuation.resume(returning: text.trimmingCharacters(in: .whitespacesAndNewlines))
                    return
                }

                // Fallback: use raw stdout
                continuation.resume(returning: outStr)
            }
        }
    }

    enum TranscriptionError: Error, LocalizedError {
        case processLaunchFailed(String)
        case processExitFailure(Int, String)
        case emptyOutput

        var errorDescription: String? {
            switch self {
            case .processLaunchFailed(let msg): return "Failed to launch transcription: \(msg)"
            case .processExitFailure(let code, let msg): return "Transcription failed (exit \(code)): \(msg)"
            case .emptyOutput: return "Transcription returned empty output"
            }
        }
    }
}
