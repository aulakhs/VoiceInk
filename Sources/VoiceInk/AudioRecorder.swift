import AVFoundation

final class AudioRecorder {
    private var recorder: AVAudioRecorder?
    private(set) var recordingURL: URL?

    func startRecording() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiceink_\(Int(Date().timeIntervalSince1970))")
            .appendingPathExtension("wav")

        // Check for available audio input
        guard let defaultInput = AVCaptureDevice.default(for: .audio) else {
            log("No audio input device found — connect a microphone")
            throw RecorderError.noMicrophone
        }
        log("Audio input: \(defaultInput.localizedName)")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let rec = try AVAudioRecorder(url: url, settings: settings)
        rec.prepareToRecord()

        guard rec.record() else {
            throw RecorderError.recordFailed
        }

        self.recorder = rec
        self.recordingURL = url
        log("Recording started: \(url.lastPathComponent)")
        return url
    }

    func stopRecording() -> URL? {
        recorder?.stop()
        recorder = nil
        log("Recording stopped")
        return recordingURL
    }

    enum RecorderError: Error, LocalizedError {
        case formatError
        case recordFailed
        case noMicrophone

        var errorDescription: String? {
            switch self {
            case .formatError: return "Could not create audio format"
            case .recordFailed: return "Failed to start recording"
            case .noMicrophone: return "No microphone found"
            }
        }
    }
}
