import SwiftUI

nonisolated enum XPReward {
    static let correctAnswer = 10
    static let flashcardReview = 5
    static let roundComplete = 20
    static let perfectRound = 50
}

/// Levels need 100, 150, 200, … more XP each: level 2 at 100 XP, 3 at 250, 4 at 450, 5 at 700.
nonisolated enum Leveling {
    static func xpRequired(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        return 25 * level * (level + 1) - 50
    }

    static func level(forXP xp: Int) -> Int {
        var level = 1
        while xpRequired(forLevel: level + 1) <= xp { level += 1 }
        return level
    }

    /// XP earned inside the current level and the size of that level.
    static func progress(forXP xp: Int) -> (current: Int, needed: Int) {
        let level = level(forXP: xp)
        let start = xpRequired(forLevel: level)
        return (xp - start, xpRequired(forLevel: level + 1) - start)
    }
}

nonisolated enum Streak {
    /// Streak after practising on `today`.
    static func updated(current: Int, lastPracticeDay: Date?, today: Date, calendar: Calendar = .current) -> Int {
        guard let lastPracticeDay else { return 1 }
        switch daysBetween(lastPracticeDay, today, calendar: calendar) {
        case 0: return max(current, 1)
        case 1: return current + 1
        default: return 1
        }
    }

    /// Streak to show before practising today: still alive if the last practice was today or yesterday.
    static func visible(current: Int, lastPracticeDay: Date?, today: Date, calendar: Calendar = .current) -> Int {
        guard let lastPracticeDay else { return 0 }
        return daysBetween(lastPracticeDay, today, calendar: calendar) <= 1 ? current : 0
    }

    private static func daysBetween(_ from: Date, _ to: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }
}

struct Badge: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let color: Color
    let isUnlocked: (ProgressSnapshot) -> Bool

    static func == (lhs: Badge, rhs: Badge) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Everything badges are judged on.
struct ProgressSnapshot {
    var learnedWords: Int
    var streak: Int
    var level: Int
    var perfectRounds: Int
    var completedCategories: Int
}

enum Badges {
    static let all: [Badge] = [
        Badge(id: "first_word", title: "Første ord", detail: "Learn your first word", icon: "sparkles", color: .yellow) { $0.learnedWords >= 1 },
        Badge(id: "words_10", title: "10 words", detail: "Learn 10 words", icon: "10.circle.fill", color: .green) { $0.learnedWords >= 10 },
        Badge(id: "words_50", title: "50 words", detail: "Learn 50 words", icon: "50.circle.fill", color: .teal) { $0.learnedWords >= 50 },
        Badge(id: "words_100", title: "100 words", detail: "Learn 100 words", icon: "books.vertical.fill", color: .blue) { $0.learnedWords >= 100 },
        Badge(id: "words_200", title: "200 words", detail: "Learn 200 words", icon: "medal.fill", color: .orange) { $0.learnedWords >= 200 },
        Badge(id: "words_450", title: "Elementary master", detail: "Learn 450 words", icon: "crown.fill", color: .yellow) { $0.learnedWords >= 450 },
        Badge(id: "words_950", title: "Intermediate master", detail: "Learn 950 words", icon: "graduationcap.fill", color: .purple) { $0.learnedWords >= 950 },
        Badge(id: "words_1950", title: "Dansk mester", detail: "Learn all 1950 words", icon: "flag.checkered", color: .red) { $0.learnedWords >= 1950 },
        Badge(id: "streak_3", title: "3-day streak", detail: "Practise 3 days in a row", icon: "flame.fill", color: .orange) { $0.streak >= 3 },
        Badge(id: "streak_7", title: "Week streak", detail: "Practise 7 days in a row", icon: "flame.circle.fill", color: .red) { $0.streak >= 7 },
        Badge(id: "streak_30", title: "Month streak", detail: "Practise 30 days in a row", icon: "calendar.badge.checkmark", color: .pink) { $0.streak >= 30 },
        Badge(id: "category_master", title: "Category master", detail: "Learn every word in one category", icon: "square.grid.3x3.fill", color: .purple) { $0.completedCategories >= 1 },
        Badge(id: "perfect_quiz", title: "Perfekt!", detail: "Finish a quiz with no mistakes", icon: "star.circle.fill", color: .yellow) { $0.perfectRounds >= 1 },
        Badge(id: "level_5", title: "Level 5", detail: "Reach level 5", icon: "trophy.fill", color: .indigo) { $0.level >= 5 },
    ]

    static func badge(id: String) -> Badge? { all.first { $0.id == id } }

    static func unlocked(for snapshot: ProgressSnapshot) -> [Badge] {
        all.filter { $0.isUnlocked(snapshot) }
    }
}
