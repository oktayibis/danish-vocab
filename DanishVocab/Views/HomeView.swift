import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var stats: [PlayerStats]
    @Query private var progress: [WordProgress]
    @State private var practice: PracticeRequest?

    private let repository = WordRepository.shared
    static let sessionSize = 10

    private var player: PlayerStats? { stats.first }
    private var learnedIds: Set<String> { Set(progress.filter(\.isLearned).map(\.wordId)) }
    private var dueCount: Int {
        let now = Date.now
        return progress.filter { SpacedRepetition.isDue(nextReview: $0.nextReview, now: now) }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    dailyPracticeCard
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Word packs").font(.title3.bold())
                        ForEach(repository.packs) { pack in
                            packRow(pack)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Hej! 👋")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    StreakBadge(streak: player?.visibleStreak() ?? 0)
                }
            }
            .navigationDestination(for: WordPack.self) { PackView(pack: $0) }
            .practiceSession($practice)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            XPBar(xp: player?.xp ?? 0)
            HStack {
                stat(value: learnedIds.count, label: "learned", icon: "checkmark.seal.fill", color: .green)
                Divider().frame(height: 32)
                stat(value: dueCount, label: "to review", icon: "arrow.triangle.2.circlepath", color: .blue)
                Divider().frame(height: 32)
                stat(value: player?.longestStreak ?? 0, label: "best streak", icon: "flame.fill", color: .orange)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private func stat(value: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon).foregroundStyle(color)
                Text("\(value)")
            }
            .font(.headline.monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var dailyPracticeCard: some View {
        Button(action: startDailyPractice) {
            HStack(spacing: 16) {
                Text("🇩🇰").font(.system(size: 48))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily practice").font(.title2.bold())
                    Text(dueCount > 0 ? "\(dueCount) words are ready to review" : "Learn \(Self.sessionSize) words with pictures")
                        .font(.subheadline)
                        .opacity(0.9)
                }
                Spacer()
                Image(systemName: "play.circle.fill").font(.system(size: 40))
            }
            .foregroundStyle(.white)
            .padding()
            .background(
                LinearGradient(colors: [Color.accentColor, .red.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func packRow(_ pack: WordPack) -> some View {
        let words = repository.words(inPack: pack.id)
        let learned = words.filter { learnedIds.contains($0.id) }.count
        let content = HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(pack.title).font(.headline)
                Text(pack.subtitle).font(.subheadline).foregroundStyle(.secondary)
                if pack.isAvailable {
                    Text("\(learned) of \(words.count) learned").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if pack.isAvailable {
                ProgressRing(value: words.isEmpty ? 0 : Double(learned) / Double(words.count))
                    .frame(width: 48, height: 48)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            } else {
                Label("Soon", systemImage: "lock.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: Capsule())
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .opacity(pack.isAvailable ? 1 : 0.6)

        if pack.isAvailable {
            NavigationLink(value: pack) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }

    private func startDailyPractice() {
        let pool = repository.packs.filter(\.isAvailable).flatMap { repository.words(inPack: $0.id) }
        let store = ProgressStore(context: modelContext)
        var rng = SystemRandomNumberGenerator()
        let words = QuizBuilder.pickWords(from: pool, states: store.reviewStates(), count: Self.sessionSize, using: &rng)
        practice = PracticeRequest(kind: .quiz, title: "Daily practice", words: words, pool: pool)
    }
}

#Preview {
    HomeView().modelContainer(for: [WordProgress.self, PlayerStats.self, EarnedBadge.self], inMemory: true)
}
