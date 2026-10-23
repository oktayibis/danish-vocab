import Foundation

/// Danish ⇄ English lookup over the bundled words.
enum DictionarySearch {
    private static let danish = Locale(identifier: "da_DK")

    /// Finds words whose Danish forms or English meaning match `query`, best matches first.
    /// "aeble", "æble" and "et æble" all find æble; "eat" finds "at spise".
    static func search(_ query: String, in words: [Word]) -> [Word] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return sorted(words) }

        let ranked: [(word: Word, score: Int)] = words.compactMap { word in
            let danishScore = word.danishForms.compactMap { form in
                variants(of: form).compactMap { score($0, query: query) }.min()
            }.min()
            let englishScore = englishTerms(word.english).compactMap { score($0, query: query) }.min()
            // Prefer a Danish hit over an English one with the same quality.
            let best = [danishScore.map { $0 * 2 }, englishScore.map { $0 * 2 + 1 }].compactMap { $0 }.min()
            return best.map { (word, $0) }
        }
        return ranked
            .sorted { $0.score != $1.score ? $0.score < $1.score : isOrderedBefore($0.word, $1.word) }
            .map(\.word)
    }

    /// Words in Danish alphabetical order (æ, ø, å last), ignoring "at" and "en"/"et".
    static func sorted(_ words: [Word]) -> [Word] {
        words.sorted(by: isOrderedBefore)
    }

    /// The letter a word is listed under in the dictionary.
    static func indexLetter(for word: Word) -> String {
        sortKey(word).first.map { String($0).uppercased(with: danish) } ?? "#"
    }

    private static func isOrderedBefore(_ a: Word, _ b: Word) -> Bool {
        let order = sortKey(a).compare(sortKey(b), options: [.caseInsensitive], locale: danish)
        return order == .orderedSame ? a.partOfSpeech.rawValue < b.partOfSpeech.rawValue : order == .orderedAscending
    }

    private static func sortKey(_ word: Word) -> String {
        word.danish.hasPrefix("at ") ? String(word.danish.dropFirst(3)) : word.danish
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
        let doubled = lower.replacingOccurrences(of: "æ", with: "ae")
            .replacingOccurrences(of: "ø", with: "oe")
            .replacingOccurrences(of: "å", with: "aa")
        let plain = lower.replacingOccurrences(of: "æ", with: "ae")
            .replacingOccurrences(of: "ø", with: "o")
            .replacingOccurrences(of: "å", with: "a")
        return [lower, doubled, plain]
    }

    /// "to live (reside), to stay" → ["to live (reside), to stay", "live", "stay"]
    private static func englishTerms(_ english: String) -> [String] {
        let lower = english.lowercased()
        let parts = lower.split(separator: ",").map { part in
            var term = part.trimmingCharacters(in: .whitespaces)
            if let paren = term.firstIndex(of: "(") { term = String(term[..<paren]).trimmingCharacters(in: .whitespaces) }
            if term.hasPrefix("to ") { term = String(term.dropFirst(3)) }
            return term
        }
        return [lower] + parts
    }
}
