import Foundation

enum PartOfSpeech: String, Codable, CaseIterable, Identifiable, Sendable {
    case noun
    case verb
    case adjective
    case adverb
    case preposition
    case pronoun
    case conjunction
    case number
    case question
    case phrase
    case interjection
    case proverb

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noun: "Nouns"
        case .verb: "Verbs"
        case .adjective: "Adjectives"
        case .adverb: "Adverbs"
        case .preposition: "Prepositions"
        case .pronoun: "Pronouns"
        case .conjunction: "Conjunctions"
        case .number: "Numbers"
        case .question: "Question words"
        case .phrase: "Phrases"
        case .interjection: "Interjections"
        case .proverb: "Proverbs"
        }
    }

    /// "noun", "verb", … for tags on dictionary rows.
    var singularTitle: String {
        switch self {
        case .noun: "noun"
        case .verb: "verb"
        case .adjective: "adjective"
        case .adverb: "adverb"
        case .preposition: "preposition"
        case .pronoun: "pronoun"
        case .conjunction: "conjunction"
        case .number: "number"
        case .question: "question word"
        case .phrase: "phrase"
        case .interjection: "interjection"
        case .proverb: "proverb"
        }
    }

    var group: WordGroup {
        switch self {
        case .noun: .nouns
        case .verb: .verbs
        case .adjective: .adjectives
        case .adverb, .preposition, .pronoun, .conjunction, .number, .question, .phrase, .interjection, .proverb: .smallWords
        }
    }
}

/// How word lists are split up on screen. Everything that isn't a noun, verb or adjective
/// is a "small word" and is told apart by its category instead.
enum WordGroup: String, CaseIterable, Identifiable, Sendable {
    case nouns
    case verbs
    case adjectives
    case smallWords

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nouns: "Nouns"
        case .verbs: "Verbs"
        case .adjectives: "Adjectives"
        case .smallWords: "Small words"
        }
    }
}

/// How a word is pictured: an emoji, an SF Symbol, or one of our own SwiftUI drawings.
enum Visual: Hashable, Sendable {
    case emoji(String)
    case symbol(String)
    case drawing(String)
}

extension Visual: Codable {
    private enum CodingKeys: String, CodingKey { case type, value }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(String.self, forKey: .value)
        switch try container.decode(String.self, forKey: .type) {
        case "emoji": self = .emoji(value)
        case "symbol": self = .symbol(value)
        case "drawing": self = .drawing(value)
        case let other:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container, debugDescription: "Unknown visual type \(other)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .emoji(let value):
            try container.encode("emoji", forKey: .type)
            try container.encode(value, forKey: .value)
        case .symbol(let value):
            try container.encode("symbol", forKey: .type)
            try container.encode(value, forKey: .value)
        case .drawing(let value):
            try container.encode("drawing", forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}

struct Word: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let danish: String
    let english: String
    let partOfSpeech: PartOfSpeech
    let category: String
    let visual: Visual
    let exampleDa: String
    let exampleEn: String

    // Nouns (plural is also the adjective plural/definite form)
    var article: String? = nil
    var plural: String? = nil

    // Adjectives: "rødt" for et-words
    var neuter: String? = nil

    // Verbs
    var present: String? = nil
    var past: String? = nil

    /// Usage tip, e.g. "object form: mig", "21 = enogtyve" or "Fedt! = Cool!".
    var note: String? = nil

    /// Mass nouns like "vand" or "kød" have no plural and are not used with en/et.
    var isUncountable: Bool { partOfSpeech == .noun && plural == nil }

    /// The form shown to the learner: "et æble" for nouns, "kød" for mass nouns, "at spise" for verbs.
    var displayDanish: String {
        if let article, !isUncountable { "\(article) \(danish)" } else { danish }
    }

    /// Extra grammar line under the word, e.g. "plural: æbler" or "spiser · spiste", followed by any note.
    var grammarHint: String? {
        let forms: String? = switch partOfSpeech {
        case .noun:
            if let plural { "plural: \(plural)" } else { article.map { "\($0)-word · uncountable" } }
        case .verb:
            if let present, let past { "present: \(present) · past: \(past)" } else { nil }
        case .adjective:
            if let neuter, let plural { "et-word: \(neuter) · plural: \(plural)" } else { nil }
        case .adverb, .preposition, .pronoun, .conjunction, .number, .question, .phrase, .interjection, .proverb:
            nil
        }
        let parts = [forms, note].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Every Danish spelling of the word, used by the dictionary search.
    var danishForms: [String] {
        var forms = [danish, displayDanish]
        if danish.hasPrefix("at ") { forms.append(String(danish.dropFirst(3))) }
        forms += [plural, neuter, present, past].compactMap { $0 }
        return forms
    }
}
