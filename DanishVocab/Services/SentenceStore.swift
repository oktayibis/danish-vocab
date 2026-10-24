import Foundation

/// A sentence from the shared pool (Data/sentences.json, built by scripts/build_sentences.swift):
/// a practical sentence for a situation, or the example sentence written for one dictionary word.
struct Sentence: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let da: String
    let en: String
    /// Situation category, e.g. "cafe". Nil for word examples.
    let c: String?
    /// "me" when the learner says it, "them" when the learner hears it.
    let who: String?
    /// The word this sentence was written for, as "lemma|pos".
    let t: String?
    /// The words it contains, as "lemma|pos".
    let k: [String]

    var isSituation: Bool { c != nil }
    var isHeard: Bool { who == "them" }
}

/// A situation such as "At the café" with its practical sentences.
struct SentenceCategory: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let emoji: String
}

/// The sentence pool: practical sentences by situation, and every sentence a word appears in.
/// Loaded on first use; the file holds ~22,000 sentences.
final class SentenceStore {
    static let shared = SentenceStore()

    let categories: [SentenceCategory]
    private let sentences: [Sentence]
    private let byCategory: [String: [Sentence]]
    /// Sentence indexes by "lemma|word group", so pack words (nouns, verbs…) and dictionary entries
    /// find the same sentences even when their part of speech is named differently.
    private let byWord: [String: [Int]]

    private struct File: Decodable {
        let categories: [SentenceCategory]
        let sentences: [Sentence]
    }

    init(bundle: Bundle = .main) {
        let file: File
        if let url = bundle.url(forResource: "sentences", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(File.self, from: data) {
            file = decoded
        } else {
            assertionFailure("Could not load sentences.json")
            file = File(categories: [], sentences: [])
        }
        categories = file.categories
        sentences = file.sentences
        byCategory = Dictionary(grouping: file.sentences.filter(\.isSituation), by: { $0.c ?? "" })
        var byWord: [String: [Int]] = [:]
        for (index, sentence) in file.sentences.enumerated() {
            for key in Set(sentence.k.map(Self.groupKey)) { byWord[key, default: []].append(index) }
        }
        self.byWord = byWord
    }

    var count: Int { sentences.count }

    func sentences(in category: String) -> [Sentence] { byCategory[category] ?? [] }

    /// Sentences containing a word: practical sentences first (they are the most useful), then the
    /// example written for this word, then other examples, shortest first.
    func sentences(containing lemma: String, partOfSpeech: PartOfSpeech, limit: Int = 20) -> [Sentence] {
        let key = "\(lemma.lowercased())|\(partOfSpeech.group.rawValue)"
        let found = (byWord[key] ?? []).map { sentences[$0] }
        func rank(_ sentence: Sentence) -> Int {
            if sentence.isSituation { return 0 }
            if let target = sentence.t, Self.groupKey(target) == key { return 1 }
            return 2
        }
        let sorted = found.sorted { a, b in
            let (ra, rb) = (rank(a), rank(b))
            return ra != rb ? ra < rb : a.da.count < b.da.count
        }
        return Array(sorted.prefix(limit))
    }

    /// The example sentence written for a dictionary word, if there is one.
    func example(for lemma: String, partOfSpeech: PartOfSpeech) -> Sentence? {
        let key = "\(lemma.lowercased())|\(partOfSpeech.group.rawValue)"
        return (byWord[key] ?? []).lazy.map { self.sentences[$0] }.first { $0.t.map(Self.groupKey) == key }
    }

    /// "spise|verb" → "spise|verbs"; small words share one group, like in the dictionary.
    private static func groupKey(_ key: String) -> String {
        guard let bar = key.lastIndex(of: "|"),
              let pos = PartOfSpeech(rawValue: String(key[key.index(after: bar)...]))
        else { return key }
        return "\(key[..<bar])|\(pos.group.rawValue)"
    }
}

/// Where learners report a wrong sentence or translation: a prefilled GitHub issue.
enum MistakeReport {
    static let repository = "https://github.com/oktayibis/danish-vocab"

    static func url(for sentence: Sentence) -> URL {
        url(title: "Sentence \(sentence.id): mistake",
            body: "Sentence: \(sentence.da)\nTranslation: \(sentence.en)\nId: \(sentence.id)\n\nWhat is wrong / suggested fix:\n")
    }

    static func url(forWord danish: String, english: String, id: String) -> URL {
        url(title: "Word \(danish): mistake",
            body: "Word: \(danish)\nMeaning: \(english)\nId: \(id)\n\nWhat is wrong / suggested fix:\n")
    }

    private static func url(title: String, body: String) -> URL {
        var components = URLComponents(string: "\(repository)/issues/new")!
        components.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "body", value: body),
            URLQueryItem(name: "labels", value: "content"),
        ]
        return components.url!
    }
}
