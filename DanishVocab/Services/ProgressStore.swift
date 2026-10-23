import Foundation
import SwiftData

enum SessionKind {
    case quiz
    case flashcards
}

/// What a finished quiz or flashcard session reports back.
struct SessionResult {
    var kind: SessionKind
    var correct: Int
    var total: Int
    /// XP already earned answer by answer (including combo bonuses).
    var answerXP: Int

    var isPerfect: Bool { kind == .quiz && total >= 5 && correct == total }
}

struct RoundSummary {
    var correct: Int
    var total: Int
    var xpEarned: Int
    var oldLevel: Int
    var newLevel: Int
    var streak: Int
    var newBadges: [Badge]

    var leveledUp: Bool { newLevel > oldLevel }
}

/// Reads and writes learning progress in SwiftData.
final class ProgressStore {
    let context: ModelContext
    let repository: WordRepository

    init(context: ModelContext, repository: WordRepository = .shared) {
        self.context = context
        self.repository = repository
    }

    func stats() -> PlayerStats {
        if let existing = try? context.fetch(FetchDescriptor<PlayerStats>()).first { return existing }
        let stats = PlayerStats()
        context.insert(stats)
        return stats
    }

    func allProgress() -> [String: WordProgress] {
        let all = (try? context.fetch(FetchDescriptor<WordProgress>())) ?? []
        return Dictionary(all.map { ($0.wordId, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func reviewStates() -> [String: ReviewState] {
        allProgress().mapValues { ReviewState(box: $0.box, nextReview: $0.nextReview) }
    }

    func progress(for wordId: String) -> WordProgress {
        let descriptor = FetchDescriptor<WordProgress>(predicate: #Predicate { $0.wordId == wordId })
        if let existing = try? context.fetch(descriptor).first { return existing }
        let progress = WordProgress(wordId: wordId)
        context.insert(progress)
        return progress
    }

    func recordAnswer(wordId: String, correct: Bool, now: Date = .now) {
        progress(for: wordId).record(correct: correct, now: now)
    }

    func earnedBadgeIds() -> Set<String> {
        Set(((try? context.fetch(FetchDescriptor<EarnedBadge>())) ?? []).map(\.badgeId))
    }

    func snapshot(today: Date = .now) -> ProgressSnapshot {
        let progress = allProgress()
        let learned = Set(progress.values.filter(\.isLearned).map(\.wordId))
        let stats = stats()
        var completedCategories = 0
        for pack in repository.packs where pack.isAvailable {
            let byCategory = Dictionary(grouping: repository.words(inPack: pack.id), by: { "\($0.partOfSpeech.rawValue).\($0.category)" })
            completedCategories += byCategory.values.filter { $0.allSatisfy { learned.contains($0.id) } }.count
        }
        return ProgressSnapshot(
            learnedWords: learned.count,
            streak: stats.visibleStreak(today: today),
            level: stats.level,
            perfectRounds: stats.perfectRounds,
            completedCategories: completedCategories)
    }

    /// Adds round XP, updates the streak, unlocks badges and saves.
    @discardableResult
    func finishSession(_ result: SessionResult, now: Date = .now) -> RoundSummary {
        let stats = stats()
        let oldLevel = stats.level

        var xp = result.answerXP
        if result.kind == .quiz { xp += XPReward.roundComplete }
        if result.isPerfect {
            xp += XPReward.perfectRound
            stats.perfectRounds += 1
        }
        stats.xp += xp
        stats.roundsPlayed += 1
        stats.currentStreak = Streak.updated(current: stats.currentStreak, lastPracticeDay: stats.lastPracticeDay, today: now)
        stats.longestStreak = max(stats.longestStreak, stats.currentStreak)
        stats.lastPracticeDay = now

        let alreadyEarned = earnedBadgeIds()
        let newBadges = Badges.unlocked(for: snapshot(today: now)).filter { !alreadyEarned.contains($0.id) }
        for badge in newBadges { context.insert(EarnedBadge(badgeId: badge.id, date: now)) }

        try? context.save()

        return RoundSummary(
            correct: result.correct,
            total: result.total,
            xpEarned: xp,
            oldLevel: oldLevel,
            newLevel: stats.level,
            streak: stats.currentStreak,
            newBadges: newBadges)
    }
}
