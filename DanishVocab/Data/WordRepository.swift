import Foundation

/// Loads word packs bundled with the app. New packs only need a JSON file and an entry in packs.json.
final class WordRepository {
    static let shared = WordRepository()

    let packs: [WordPack]
    private let wordsByPack: [String: [Word]]
    private let wordsById: [String: Word]
    private let packIdByWordId: [String: String]

    init(bundle: Bundle = .main) {
        let packs = Self.decode([WordPack].self, file: "packs.json", bundle: bundle) ?? []
        var wordsByPack: [String: [Word]] = [:]
        for pack in packs where pack.isAvailable {
            wordsByPack[pack.id] = pack.files.flatMap { Self.decode([Word].self, file: $0, bundle: bundle) ?? [] }
        }
        self.packs = packs
        self.wordsByPack = wordsByPack
        self.wordsById = Dictionary(wordsByPack.values.joined().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.packIdByWordId = Dictionary(
            wordsByPack.flatMap { packId, words in words.map { ($0.id, packId) } },
            uniquingKeysWith: { first, _ in first })
    }

    var allWords: [Word] { packs.flatMap { words(inPack: $0.id) } }

    func words(inPack packId: String) -> [Word] { wordsByPack[packId] ?? [] }

    func words(inPack packId: String, partOfSpeech: PartOfSpeech? = nil, category: String? = nil) -> [Word] {
        words(inPack: packId).filter { word in
            (partOfSpeech == nil || word.partOfSpeech == partOfSpeech) && (category == nil || word.category == category)
        }
    }

    func words(inPack packId: String, group: WordGroup, category: String? = nil) -> [Word] {
        words(inPack: packId).filter { word in
            word.partOfSpeech.group == group && (category == nil || word.category == category)
        }
    }

    /// Category ids in the order they first appear in the pack.
    func categories(inPack packId: String, group: WordGroup) -> [String] {
        var seen = Set<String>()
        return words(inPack: packId, group: group).compactMap { seen.insert($0.category).inserted ? $0.category : nil }
    }

    func word(id: String) -> Word? { wordsById[id] }

    func pack(forWordId id: String) -> WordPack? {
        packIdByWordId[id].flatMap { packId in packs.first { $0.id == packId } }
    }

    private static func decode<T: Decodable>(_ type: T.Type, file: String, bundle: Bundle) -> T? {
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            assertionFailure("Missing bundled file \(file)")
            return nil
        }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            assertionFailure("Could not decode \(file): \(error)")
            return nil
        }
    }
}
