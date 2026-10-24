import Foundation

/// Danish ⇄ English lookup over the learning-pack words and the open dictionary.
/// Search keys and alphabetical sections are computed once, so typing stays fast with ~25,000 words.
final class DictionaryLookup {
    static let shared = DictionaryLookup()

    /// Every word once, in Danish alphabetical order (æ, ø, å last). Pack words replace the
    /// dictionary entry for the same word.
    let items: [DictionaryItem]
    /// Synonyms and antonyms by "lemma|word group", in both directions: Wiktionary often lists a
    /// pair on one side only (glad → fornøjet), and the other side should show it too.
    private let synonyms: [String: Set<String>]
    private let antonyms: [String: Set<String>]
    private let itemsByLemma: [String: [DictionaryItem]]
    /// Built on the first search rather than up front, so opening the dictionary is quick.
    private lazy var keys: [SearchKeys] = items.map { Self.searchKeys(for: $0) }
    private var sectionCache: [String: [(letter: String, items: [DictionaryItem])]] = [:]

    private struct SearchKeys {
        let danish: [String]
        let english: [String]
        /// Lower comes first among equally good matches: pack words, then frequent words.
        let priority: Int
        /// All keys as UTF-8, so most words can be ruled out with one fast byte search.
        let blob: [UInt8]

        init(danish: [String], english: [String], priority: Int) {
            self.danish = danish
            self.english = english
            self.priority = priority
            blob = Array((danish + english).joined(separator: "\n").utf8)
        }

        func mightContain(_ query: [UInt8]) -> Bool {
            blob.withUnsafeBytes { haystack in
                query.withUnsafeBytes { needle in
                    memmem(haystack.baseAddress, haystack.count, needle.baseAddress, needle.count) != nil
                }
            }
        }
    }

    init(bundle: Bundle = .main) {
        let repository = bundle == .main ? WordRepository.shared : WordRepository(bundle: bundle)
        let entries = Self.loadEntries(bundle: bundle)
        let packItems = repository.allWords.map(DictionaryItem.word)

        func matchKey(_ lemma: String, _ pos: PartOfSpeech) -> String { "\(lemma)|\(pos.group.rawValue)" }
        let packKeys = Set(packItems.map { matchKey($0.lemma, $0.partOfSpeech) })
        let extra = entries.map(DictionaryItem.entry).filter { !packKeys.contains(matchKey($0.lemma, $0.partOfSpeech)) }

        // Collation keys are computed once; computing them inside the comparator made start-up slow.
        let all = (packItems + extra).map { ($0, Self.collationKey($0)) }.sorted { $0.1 < $1.1 }.map(\.0)
        items = all
        var synonyms: [String: Set<String>] = [:]
        var antonyms: [String: Set<String>] = [:]
        for entry in entries {
            let group = entry.p.group
            for other in entry.syn ?? [] {
                synonyms[matchKey(entry.w.lowercased(), entry.p), default: []].insert(other)
                synonyms["\(other.lowercased())|\(group.rawValue)", default: []].insert(entry.w)
            }
            for other in entry.ant ?? [] {
                antonyms[matchKey(entry.w.lowercased(), entry.p), default: []].insert(other)
                antonyms["\(other.lowercased())|\(group.rawValue)", default: []].insert(entry.w)
            }
        }
        self.synonyms = synonyms
        self.antonyms = antonyms
        itemsByLemma = Dictionary(grouping: all, by: \.lemma)
    }

    private static func loadEntries(bundle: Bundle) -> [DictionaryEntry] {
        guard let url = bundle.url(forResource: "dictionary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([DictionaryEntry].self, from: data)
        else {
            assertionFailure("Could not load dictionary.json")
            return []
        }
        return entries
    }

    // MARK: - Search

    /// Finds words whose Danish forms or English meanings match `query`, best matches first.
    /// "aeble", "æble" and "et æble" all find æble; "eat" finds "at spise"; "spiste" finds it too.
    func search(_ query: String, group: WordGroup? = nil, limit: Int = 200) -> [DictionaryItem] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return Array(items.lazy.filter { group == nil || $0.partOfSpeech.group == group }.prefix(limit))
        }
        // One letter matches almost everything, so list the words that start with it instead.
        if query.count == 1 {
            return Array(items.lazy.filter { $0.lemma.hasPrefix(query) && (group == nil || $0.partOfSpeech.group == group) }.prefix(limit))
        }
        let bytes = Array(query.utf8)
        var matches: [(index: Int, score: Int)] = []
        for (index, key) in keys.enumerated() where key.mightContain(bytes) {
            if let group, items[index].partOfSpeech.group != group { continue }
            let danish = key.danish.lazy.compactMap { Self.score($0, query: query) }.min()
            let english = key.english.lazy.compactMap { Self.score($0, query: query) }.min()
            // Prefer a Danish hit over an English one of the same quality.
            if let best = [danish.map { $0 * 2 }, english.map { $0 * 2 + 1 }].compactMap({ $0 }).min() {
                matches.append((index, best))
            }
        }
        matches.sort { a, b in
            if a.score != b.score { return a.score < b.score }
            if keys[a.index].priority != keys[b.index].priority { return keys[a.index].priority < keys[b.index].priority }
            return a.index < b.index
        }
        return matches.prefix(limit).map { items[$0.index] }
    }

    /// Alphabetical sections for browsing, computed once per filter.
    func sections(group: WordGroup?) -> [(letter: String, items: [DictionaryItem])] {
        let cacheKey = group?.rawValue ?? "all"
        if let cached = sectionCache[cacheKey] { return cached }
        var sections: [(letter: String, items: [DictionaryItem])] = []
        for item in items where group == nil || item.partOfSpeech.group == group {
            let letter = Self.indexLetter(for: item)
            if sections.last?.letter == letter {
                sections[sections.count - 1].items.append(item)
            } else {
                sections.append((letter, [item]))
            }
        }
        sectionCache[cacheKey] = sections
        return sections
    }

    // MARK: - Related words

    /// The row to open for a word mentioned as a synonym or antonym, preferring the same part of speech.
    func item(for word: String, preferring pos: PartOfSpeech? = nil) -> DictionaryItem? {
        let candidates = itemsByLemma[word.lowercased()] ?? []
        return candidates.first { $0.partOfSpeech == pos } ?? candidates.first
    }

    /// Synonyms and antonyms of a word, from either side of each Wiktionary pair.
    func related(to item: DictionaryItem) -> (synonyms: [String], antonyms: [String]) {
        let key = "\(item.lemma)|\(item.partOfSpeech.group.rawValue)"
        func list(_ words: Set<String>?) -> [String] {
            (words ?? []).filter { $0.lowercased() != item.lemma }.sorted()
        }
        return (list(synonyms[key]), list(antonyms[key]))
    }

    func related(to word: Word) -> (synonyms: [String], antonyms: [String]) { related(to: .word(word)) }

    // MARK: - Helpers

    static func indexLetter(for item: DictionaryItem) -> String {
        guard let first = item.lemma.first, first.isLetter else { return "#" }
        let letter = String(first)
        // Æ, Ø and Å are letters of their own; other accents (é, ü) are filed under the plain letter.
        let filed = ["æ", "ø", "å"].contains(letter) ? letter : letter.folding(options: .diacriticInsensitive, locale: nil)
        return filed.uppercased()
    }

    /// Sorts like a Danish dictionary: a–z, then æ, ø, å. Pack words come before dictionary
    /// entries for the same word.
    private static func collationKey(_ item: DictionaryItem) -> String {
        var letters = item.lemma
        if letters.unicodeScalars.contains(where: { !$0.isASCII }) {
            letters = letters
                .replacingOccurrences(of: "æ", with: "{")
                .replacingOccurrences(of: "ø", with: "|")
                .replacingOccurrences(of: "å", with: "}")
                .folding(options: .diacriticInsensitive, locale: nil)
        }
        let source = if case .word = item { "0" } else { "1" }
        return "\(letters)\u{1}\(source)\(item.partOfSpeech.rawValue)"
    }

    private static func searchKeys(for item: DictionaryItem) -> SearchKeys {
        switch item {
        case .word(let word):
            return SearchKeys(danish: word.danishForms.flatMap(variants), english: englishTerms(word.english), priority: 0)
        case .entry(let entry):
            return SearchKeys(danish: entry.danishForms.flatMap(variants),
                              english: entry.m.flatMap(englishTerms),
                              priority: entry.r ?? 1_000_000)
        }
    }

    /// 0 exact, 1 prefix, 2 starts a later word, 3 anywhere.
    private static func score(_ text: String, query: String) -> Int? {
        if text == query { return 0 }
        if text.hasPrefix(query) { return 1 }
        if text.contains(" " + query) { return 2 }
        if text.contains(query) { return 3 }
        return nil
    }

    /// The text as written plus spellings without æ, ø and å, for people on a non-Danish keyboard.
    private static func variants(of text: String) -> [String] {
        let lower = text.lowercased()
        guard lower.contains(where: { $0 == "æ" || $0 == "ø" || $0 == "å" }) else { return [lower] }
        let doubled = lower.replacingOccurrences(of: "æ", with: "ae")
            .replacingOccurrences(of: "ø", with: "oe")
            .replacingOccurrences(of: "å", with: "aa")
        let plain = lower.replacingOccurrences(of: "æ", with: "ae")
            .replacingOccurrences(of: "ø", with: "o")
            .replacingOccurrences(of: "å", with: "a")
        return Array(Set([lower, doubled, plain]))
    }

    /// "to live (reside), to stay" → ["to live (reside), to stay", "live", "stay"]
    private static func englishTerms(_ english: String) -> [String] {
        let lower = english.lowercased()
        let parts = lower.split(whereSeparator: { $0 == "," || $0 == ";" }).map { part in
            var term = part.trimmingCharacters(in: .whitespaces)
            if let paren = term.firstIndex(of: "(") { term = String(term[..<paren]).trimmingCharacters(in: .whitespaces) }
            if term.hasPrefix("to ") { term = String(term.dropFirst(3)) }
            return term
        }
        return [lower] + parts
    }
}
