import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var stats: [PlayerStats]
    @Query private var progress: [WordProgress]
    @Query private var badges: [EarnedBadge]
    @State private var confirmReset = false

    private var player: PlayerStats? { stats.first }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    XPBar(xp: player?.xp ?? 0).padding(.vertical, 6)
                }
                Section("Streak") {
                    row("Current streak", value: "\(player?.visibleStreak() ?? 0) days", icon: "flame.fill", color: .orange)
                    row("Longest streak", value: "\(player?.longestStreak ?? 0) days", icon: "trophy.fill", color: .yellow)
                }
                Section("Words") {
                    row("Learned", value: "\(progress.filter(\.isLearned).count)", icon: "checkmark.seal.fill", color: .green)
                    row("Seen", value: "\(progress.count)", icon: "eye.fill", color: .blue)
                    row("Correct answers", value: "\(progress.reduce(0) { $0 + $1.correct })", icon: "hand.thumbsup.fill", color: .mint)
                }
                Section("Games") {
                    row("Total XP", value: "\(player?.xp ?? 0)", icon: "star.fill", color: .yellow)
                    row("Rounds played", value: "\(player?.roundsPlayed ?? 0)", icon: "gamecontroller.fill", color: .purple)
                    row("Perfect quizzes", value: "\(player?.perfectRounds ?? 0)", icon: "star.circle.fill", color: .orange)
                }
                Section {
                    Button("Reset all progress", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("Profile")
            .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive, action: resetProgress)
            } message: {
                Text("Your XP, streak, badges and learned words will be deleted.")
            }
        }
    }

    private func row(_ title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Label(title, systemImage: icon).foregroundStyle(color, .primary)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private func resetProgress() {
        try? modelContext.delete(model: WordProgress.self)
        try? modelContext.delete(model: PlayerStats.self)
        try? modelContext.delete(model: EarnedBadge.self)
        try? modelContext.save()
    }
}
