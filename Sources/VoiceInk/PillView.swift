import SwiftUI

struct PillView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 10) {
            icon
            text
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(minWidth: 200)
        .background(backgroundShape)
        .animation(.easeInOut(duration: 0.2), value: appState.state)
    }

    @ViewBuilder
    private var icon: some View {
        switch appState.state {
        case .recording:
            PulsingMicIcon()
        case .transcribing:
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.8)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 16))
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 16))
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private var text: some View {
        switch appState.state {
        case .recording:
            HStack(spacing: 6) {
                Text(formatDuration(appState.recordingDuration))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                AnimatedDotsText(base: "Listening")
            }
        case .transcribing:
            AnimatedDotsText(base: "Transcribing")
        case .done(let result):
            Text(result.prefix(40) + (result.count > 40 ? "..." : ""))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        case .error(let msg):
            Text(msg.prefix(40) + (msg.count > 40 ? "..." : ""))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        case .idle:
            EmptyView()
        }
    }

    private var backgroundShape: some View {
        Capsule()
            .fill(backgroundColor)
            .overlay(
                Capsule()
                    .strokeBorder(borderColor, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
    }
    
    private var backgroundColor: Color {
        switch appState.state {
        case .recording: return Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.95)
        case .transcribing: return Color(red: 0.1, green: 0.3, blue: 0.5).opacity(0.95)
        case .done: return Color(red: 0.1, green: 0.4, blue: 0.2).opacity(0.95)
        case .error: return Color(red: 0.5, green: 0.1, blue: 0.1).opacity(0.95)
        case .idle: return Color.gray.opacity(0.9)
        }
    }

    private var borderColor: Color {
        switch appState.state {
        case .recording: return .red.opacity(0.6)
        case .transcribing: return .blue.opacity(0.4)
        case .done: return .green.opacity(0.4)
        case .error: return .red.opacity(0.6)
        case .idle: return .clear
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let secs = Int(t)
        let mins = secs / 60
        let rem = secs % 60
        return String(format: "%d:%02d", mins, rem)
    }
}

struct PulsingMicIcon: View {
    @State private var isPulsing = false

    var body: some View {
        Image(systemName: "mic.fill")
            .foregroundStyle(.white)
            .font(.system(size: 18, weight: .bold))
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 1.0 : 0.8)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

struct AnimatedDotsText: View {
    let base: String
    @State private var dotCount = 0

    var body: some View {
        // Use fixed-width text so dots don't cause layout jitter
        Text(base + String(repeating: ".", count: dotCount) + String(repeating: " ", count: 3 - dotCount))
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .fixedSize()
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                    dotCount = (dotCount + 1) % 4
                }
            }
    }
}
