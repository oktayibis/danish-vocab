import SwiftUI

struct RoundResultView: View {
    let summary: RoundSummary
    let title: String
    let onDone: () -> Void

    @State private var appeared = false

    private var headline: String {
        let ratio = summary.total == 0 ? 0 : Double(summary.correct) / Double(summary.total)
        switch ratio {
        case 1: return "Perfekt! 🎉"
        case 0.7...: return "Godt klaret! 💪"
        case 0.4...: return "Godt gået! 🙂"
        default: return "Øvelse gør mester! 📚"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(headline)
                    .font(.largeTitle.bold())
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .padding(.top, 40)

                Text("\(summary.correct) of \(summary.total) correct · \(title)")
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    resultTile(value: "+\(summary.xpEarned)", label: "XP", icon: "star.fill", color: .yellow)
                    resultTile(value: "\(summary.streak)", label: summary.streak == 1 ? "day streak" : "days streak", icon: "flame.fill", color: .orange)
                }

                if summary.leveledUp {
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.indigo)
                            .symbolEffect(.bounce, value: appeared)
                        Text("Level up! You are now level \(summary.newLevel)").font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                }

                if !summary.newBadges.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("New badges").font(.headline)
                        ForEach(summary.newBadges) { badge in
                            HStack(spacing: 12) {
                                BadgeIcon(badge: badge, unlocked: true, size: 48)
                                VStack(alignment: .leading) {
                                    Text(badge.title).font(.subheadline.bold())
                                    Text(badge.detail).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                }

                Button(action: onDone) {
                    Text("Done").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.5)) { appeared = true }
        }
        .sensoryFeedback(.success, trigger: appeared)
    }

    private func resultTile(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title).foregroundStyle(color)
            Text(value).font(.title.bold().monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    RoundResultView(
        summary: RoundSummary(correct: 9, total: 10, xpEarned: 125, oldLevel: 1, newLevel: 2, streak: 3,
                              newBadges: [Badges.all[0], Badges.all[5]]),
        title: "Daily practice") {}
}
