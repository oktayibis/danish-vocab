import Foundation

struct ReviewState: Hashable {
    var box: Int
    var nextReview: Date
}

enum QuizMode: CaseIterable {
    /// See the picture, pick the Danish word.
    case pictureToWord
    /// See the Danish word, pick the picture.
    case wordToPicture
    /// Hear the word, pick the picture.
    case listenToPicture
}

struct QuizQuestion: Identifiable, Hashable {
    let id = UUID()
    let mode: QuizMode
    let answer: Word
    let options: [Word]
}

enum QuizBuilder {
    static let optionCount = 4

    /// Picks words to practise: due reviews first (weakest first), then new words in pack order, then anything else.
    static func pickWords<R: RandomNumberGenerator>(
        from pool: [Word],
        states: [String: ReviewState],
        count: Int,
        now: Date = .now,
        using rng: inout R
    ) -> [Word] {
        let due = pool
            .filter { states[$0.id].map { SpacedRepetition.isDue(nextReview: $0.nextReview, now: now) } ?? false }
            .shuffled(using: &rng)
            .sorted { states[$0.id]!.box < states[$1.id]!.box }
        // Introduce new words a few at a time, in pack order, so beginners meet the basics first.
        let unseen = Array(pool.filter { states[$0.id] == nil }.prefix(count)).shuffled(using: &rng)
        let picked = Set((due + unseen).map(\.id))
        let rest = pool.filter { !picked.contains($0.id) }.shuffled(using: &rng)
        return Array((due + unseen + rest).prefix(count))
    }

    static func makeQuestions<R: RandomNumberGenerator>(
        for words: [Word],
        pool: [Word],
        modes: [QuizMode] = QuizMode.allCases,
        using rng: inout R
    ) -> [QuizQuestion] {
        words.map { answer in
            QuizQuestion(
                mode: modes.randomElement(using: &rng) ?? .pictureToWord,
                answer: answer,
                options: options(for: answer, pool: pool, using: &rng))
        }
    }

    /// The answer plus distractors of the same part of speech, each with a different word and picture.
    static func options<R: RandomNumberGenerator>(for answer: Word, pool: [Word], using rng: inout R) -> [Word] {
        var chosen = [answer]
        let samePart = pool.filter { $0.partOfSpeech == answer.partOfSpeech }.shuffled(using: &rng)
        let others = pool.filter { $0.partOfSpeech != answer.partOfSpeech }.shuffled(using: &rng)
        for candidate in samePart + others where chosen.count < optionCount {
            let clashes = chosen.contains {
                $0.id == candidate.id || $0.visual == candidate.visual || $0.displayDanish == candidate.displayDanish
            }
            if !clashes { chosen.append(candidate) }
        }
        return chosen.shuffled(using: &rng)
    }
}
