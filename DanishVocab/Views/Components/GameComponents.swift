import SwiftUI

struct XPBar: View {
    let xp: Int

    var body: some View {
        let progress = Leveling.progress(forXP: xp)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Level \(Leveling.level(forXP: xp))", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(.yellow, .primary)
                Spacer()
                Text("\(progress.current) / \(progress.needed) XP")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(progress.current), total: Double(progress.needed))
                .tint(.yellow)
        }
    }
}

struct StreakBadge: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(streak > 0 ? .orange : .gray)
                .symbolEffect(.bounce, value: streak)
            Text("\(streak)")
                .font(.headline.monospacedDigit())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.orange.opacity(streak > 0 ? 0.15 : 0.05), in: Capsule())
        .accessibilityLabel("\(streak) day streak")
    }
}

struct ProgressRing: View {
    let value: Double
    var color: Color = .accentColor
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, value)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((value * 100).rounded()))%")
                .font(.caption2.bold().monospacedDigit())
        }
    }
}

struct SpeakButton: View {
    private let speak: () -> Void
    private let size: Font

    /// Speaks a word, using its recorded clip when there is one.
    init(word: Word, size: Font = .title2) {
        self.speak = { SpeechService.shared.speak(word) }
        self.size = size
    }

    /// Speaks any text, such as an example sentence, with the device voice.
    init(text: String, size: Font = .title2) {
        self.speak = { SpeechService.shared.speak(text) }
        self.size = size
    }

    var body: some View {
        Button(action: speak) {
            Image(systemName: "speaker.wave.2.fill")
                .font(size)
                .padding(10)
                .background(.tint.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .accessibilityLabel("Play pronunciation")
    }
}

struct BadgeIcon: View {
    let badge: Badge
    let unlocked: Bool
    var size: CGFloat = 56

    var body: some View {
        Image(systemName: badge.icon)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(unlocked ? .white : .secondary)
            .frame(width: size, height: size)
            .background(unlocked ? AnyShapeStyle(badge.color.gradient) : AnyShapeStyle(.quaternary), in: Circle())
            .overlay {
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: size * 0.2))
                        .foregroundStyle(.secondary)
                        .offset(x: size * 0.32, y: size * 0.32)
                }
            }
    }
}
