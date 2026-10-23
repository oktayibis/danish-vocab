import Foundation
import Testing
@testable import DanishVocab

struct SpacedRepetitionTests {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Copenhagen")!
        return calendar
    }

    @Test func correctMovesUpAndCapsAtMaxBox() {
        #expect(SpacedRepetition.nextBox(from: 0, correct: true) == 1)
        #expect(SpacedRepetition.nextBox(from: 4, correct: true) == 5)
        #expect(SpacedRepetition.nextBox(from: 5, correct: true) == 5)
    }

    @Test func wrongResetsToZero() {
        #expect(SpacedRepetition.nextBox(from: 4, correct: false) == 0)
    }

    @Test func reviewDatesFollowIntervals() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 18))!
        #expect(SpacedRepetition.nextReview(forBox: 0, from: now, calendar: calendar) == now)
        let box3 = SpacedRepetition.nextReview(forBox: 3, from: now, calendar: calendar)
        #expect(box3 == calendar.date(from: DateComponents(year: 2026, month: 3, day: 14)))
    }

    @Test func learnedFromBoxThree() {
        #expect(!SpacedRepetition.isLearned(box: 2))
        #expect(SpacedRepetition.isLearned(box: 3))
    }

    @Test func pickWordsPrefersDueThenNew() {
        let words = WordRepository(bundle: Bundle(for: WordRepository.self)).words(inPack: "beginner")
        let now = Date.now
        let states: [String: ReviewState] = [
            words[50].id: ReviewState(box: 2, nextReview: now.addingTimeInterval(-60)),
            words[51].id: ReviewState(box: 4, nextReview: now.addingTimeInterval(86_400 * 3)),
        ]
        var rng = SystemRandomNumberGenerator()
        let picked = QuizBuilder.pickWords(from: words, states: states, count: 10, now: now, using: &rng)
        #expect(picked.count == 10)
        #expect(picked.first == words[50])
        #expect(!picked.contains(words[51]))
        #expect(Set(picked.map(\.id)).count == 10)
    }
}

struct GamificationTests {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Copenhagen")!
        return calendar
    }

    func day(_ d: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: d, hour: hour))!
    }

    @Test func levelThresholds() {
        #expect(Leveling.level(forXP: 0) == 1)
        #expect(Leveling.level(forXP: 99) == 1)
        #expect(Leveling.level(forXP: 100) == 2)
        #expect(Leveling.level(forXP: 250) == 3)
        #expect(Leveling.level(forXP: 450) == 4)
        #expect(Leveling.level(forXP: 700) == 5)
        let progress = Leveling.progress(forXP: 175)
        #expect(progress.current == 75)
        #expect(progress.needed == 150)
    }

    @Test func streakStartsAtOne() {
        #expect(Streak.updated(current: 0, lastPracticeDay: nil, today: day(10), calendar: calendar) == 1)
    }

    @Test func streakSameDayStaysTheSame() {
        #expect(Streak.updated(current: 4, lastPracticeDay: day(10, hour: 8), today: day(10, hour: 22), calendar: calendar) == 4)
    }

    @Test func streakNextDayIncrements() {
        #expect(Streak.updated(current: 4, lastPracticeDay: day(10, hour: 23), today: day(11, hour: 7), calendar: calendar) == 5)
    }

    @Test func streakSkippedDayResets() {
        #expect(Streak.updated(current: 4, lastPracticeDay: day(10), today: day(12), calendar: calendar) == 1)
        #expect(Streak.visible(current: 4, lastPracticeDay: day(10), today: day(11), calendar: calendar) == 4)
        #expect(Streak.visible(current: 4, lastPracticeDay: day(10), today: day(12), calendar: calendar) == 0)
    }

    @Test func badgesUnlockFromSnapshot() {
        let none = ProgressSnapshot(learnedWords: 0, streak: 0, level: 1, perfectRounds: 0, completedCategories: 0)
        #expect(Badges.unlocked(for: none).isEmpty)

        let some = ProgressSnapshot(learnedWords: 12, streak: 3, level: 5, perfectRounds: 1, completedCategories: 0)
        let ids = Set(Badges.unlocked(for: some).map(\.id))
        #expect(ids == ["first_word", "words_10", "streak_3", "perfect_quiz", "level_5"])
    }
}
