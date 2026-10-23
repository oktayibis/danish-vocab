import SwiftData
import SwiftUI

struct BadgesView: View {
    @Query(sort: \EarnedBadge.date) private var earned: [EarnedBadge]

    private var earnedIds: Set<String> { Set(earned.map(\.badgeId)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text("\(earnedIds.count) of \(Badges.all.count) unlocked")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 16)], spacing: 20) {
                    ForEach(Badges.all) { badge in
                        let unlocked = earnedIds.contains(badge.id)
                        VStack(spacing: 8) {
                            BadgeIcon(badge: badge, unlocked: unlocked, size: 72)
                            Text(badge.title).font(.subheadline.bold()).multilineTextAlignment(.center)
                            Text(badge.detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .opacity(unlocked ? 1 : 0.6)
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(unlocked ? "Unlocked" : "Locked")
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Badges")
        }
    }
}
