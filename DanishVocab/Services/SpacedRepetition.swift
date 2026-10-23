import Foundation

/// Leitner-box scheduling. Correct answers move a word up one box, mistakes send it back to box 0.
nonisolated enum SpacedRepetition {
    /// Days until the next review, indexed by box.
    static let intervals = [0, 1, 2, 4, 7, 14]
    static let maxBox = intervals.count - 1
    /// A word counts as learned from this box on.
    static let learnedBox = 3

    static func nextBox(from box: Int, correct: Bool) -> Int {
        correct ? min(box + 1, maxBox) : 0
    }

    static func nextReview(forBox box: Int, from date: Date, calendar: Calendar = .current) -> Date {
        let days = intervals[max(0, min(box, maxBox))]
        if days == 0 { return date }
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: days, to: startOfDay) ?? date
    }

    static func isLearned(box: Int) -> Bool { box >= learnedBox }

    static func isDue(nextReview: Date, now: Date) -> Bool { nextReview <= now }
}
