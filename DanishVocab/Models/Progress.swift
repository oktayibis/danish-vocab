import Foundation
import SwiftData

/// Leitner state for one word.
@Model
final class WordProgress {
    @Attribute(.unique) var wordId: String
    var box: Int
    var nextReview: Date
    var correct: Int
    var wrong: Int
    var lastSeen: Date?

    init(wordId: String, now: Date = .now) {
        self.wordId = wordId
        self.box = 0
        self.nextReview = now
        self.correct = 0
        self.wrong = 0
        self.lastSeen = nil
    }

    var isLearned: Bool { SpacedRepetition.isLearned(box: box) }

    func record(correct isCorrect: Bool, now: Date = .now, calendar: Calendar = .current) {
        if isCorrect { correct += 1 } else { wrong += 1 }
        box = SpacedRepetition.nextBox(from: box, correct: isCorrect)
        nextReview = SpacedRepetition.nextReview(forBox: box, from: now, calendar: calendar)
        lastSeen = now
    }
}

/// The single player profile: XP, streak and round counters.
@Model
final class PlayerStats {
    var xp: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastPracticeDay: Date?
    var roundsPlayed: Int
    var perfectRounds: Int

    init() {
        xp = 0
        currentStreak = 0
        longestStreak = 0
        lastPracticeDay = nil
        roundsPlayed = 0
        perfectRounds = 0
    }

    var level: Int { Leveling.level(forXP: xp) }

    /// Streak as it should be shown today (0 if a day was missed).
    func visibleStreak(today: Date = .now, calendar: Calendar = .current) -> Int {
        Streak.visible(current: currentStreak, lastPracticeDay: lastPracticeDay, today: today, calendar: calendar)
    }
}

@Model
final class EarnedBadge {
    @Attribute(.unique) var badgeId: String
    var date: Date

    init(badgeId: String, date: Date = .now) {
        self.badgeId = badgeId
        self.date = date
    }
}
