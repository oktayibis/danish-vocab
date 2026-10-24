import Foundation

/// A word from the open dictionary (Data/dictionary.json, built from Wiktionary by
/// scripts/import_dictionary.swift). Unlike pack words it has no picture, quiz or recording.
struct DictionaryEntry: Decodable, Hashable {
    /// The word as listed, without "at" or "en"/"et".
    let w: String
    let p: PartOfSpeech
    /// "en" or "et" for nouns.
    let g: String?
    /// English meanings, most common first.
    let m: [String]
    /// Inflected forms, e.g. ["definite": "huset", "plural": "huse"].
    let f: [String: String]?
    let ipa: String?
    let syn: [String]?
    let ant: [String]?
    /// Frequency rank: 1 is the most used word. Nil for rare words.
    let r: Int?

    var displayDanish: String {
        switch p {
        case .noun: g.map { "\($0) \(w)" } ?? w
        case .verb: "at \(w)"
        default: w
        }
    }

    var grammarHint: String? {
        guard let f else { return nil }
        let order: [(key: String, label: String)] = switch p {
        case .noun: [("plural", "plural"), ("definite", "the"), ("definitePlural", "the (plural)")]
        case .verb: [("present", "present"), ("past", "past"), ("perfect", "perfect"), ("imperative", "imperative")]
        case .adjective: [("neuter", "et-word"), ("plural", "plural"), ("comparative", "more"), ("superlative", "most")]
        default: []
        }
        let parts = order.compactMap { item in f[item.key].map { "\(item.label): \($0)" } }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var danishForms: [String] { [w, displayDanish] + (f.map { Array($0.values) } ?? []) }
}

/// One row of the dictionary: a learning-pack word or an open-dictionary entry.
enum DictionaryItem: Identifiable, Hashable {
    case word(Word)
    case entry(DictionaryEntry)

    var id: String {
        switch self {
        case .word(let word): word.id
        case .entry(let entry): "dict.\(entry.w).\(entry.p.rawValue)"
        }
    }

    /// The word itself: "at spise" for pack verbs, "spise" for dictionary verbs.
    var danish: String {
        switch self {
        case .word(let word): word.danish
        case .entry(let entry): entry.w
        }
    }

    var displayDanish: String {
        switch self {
        case .word(let word): word.displayDanish
        case .entry(let entry): entry.displayDanish
        }
    }

    var partOfSpeech: PartOfSpeech {
        switch self {
        case .word(let word): word.partOfSpeech
        case .entry(let entry): entry.p
        }
    }

    /// Short English meaning for list rows.
    var english: String {
        switch self {
        case .word(let word): word.english
        case .entry(let entry): entry.m.prefix(2).joined(separator: "; ")
        }
    }

    var grammarHint: String? {
        switch self {
        case .word(let word): word.grammarHint
        case .entry(let entry): entry.grammarHint
        }
    }

    /// The lemma used to match pack words with dictionary entries: "spise", "hus".
    var lemma: String {
        let text = danish.lowercased()
        return text.hasPrefix("at ") && partOfSpeech == .verb ? String(text.dropFirst(3)) : text
    }
}
