import Foundation

// Builds DanishVocab/Data/sentences.json, the shared pool of example sentences:
//   - scripts/sentences/situations.json: practical sentences by situation (café, doctor, …),
//     each listing the words it uses as headword + part of speech
//   - scripts/sentences/words.json: one example sentence per dictionary word that is not in a pack
// Every sentence is linked to the pack words and dictionary entries it contains, as "lemma|pos" keys,
// so a word can list the sentences it appears in.
//
// The sentences were written with Claude and reviewed; see README.
//
// Run from the repository root:
//   swift scripts/build_sentences.swift

// MARK: - Input

struct SituationWord: Decodable { let w: String; let p: String }
struct SituationSentence: Decodable { let da: String; let en: String; let who: String; let words: [SituationWord] }
struct Situation: Decodable { let id: String; let title: String; let emoji: String; let sentences: [SituationSentence] }
struct Situations: Decodable { let categories: [Situation] }
struct WordSentence: Decodable { let id: String; let da: String; let en: String }

struct DictEntry: Decodable { let w: String; let p: String; let f: [String: String]? }
struct Pack: Decodable { let files: [String] }
struct PackWord: Decodable {
    let danish: String
    let partOfSpeech: String
    let plural: String?
    let neuter: String?
    let present: String?
    let past: String?
}

// MARK: - Output (short keys keep the bundled file small)

struct OutCategory: Encodable { let id: String; let title: String; let emoji: String }
struct OutSentence: Encodable {
    let id: String
    let da: String
    let en: String
    var c: String?        // situation category
    var who: String?      // "me": the learner says it, "them": the learner hears it
    var t: String?        // the word this sentence was written for
    var k: [String]       // words it contains, "lemma|pos"
}
struct Output: Encodable { let categories: [OutCategory]; let sentences: [OutSentence] }

func decode<T: Decodable>(_ type: T.Type, _ path: String) -> T {
    do { return try JSONDecoder().decode(type, from: Data(contentsOf: URL(fileURLWithPath: path))) }
    catch { fatalError("\(path): \(error)") }
}

// MARK: - Word index

func group(_ pos: String) -> String {
    ["noun": "noun", "verb": "verb", "adjective": "adjective"][pos] ?? "small"
}

var keys = Set<String>()
var posByLemma: [String: [String]] = [:]       // "spise" → ["verb"]
var keysByForm: [String: Set<String>] = [:]    // "spiste" → ["spise|verb"]

func add(lemma: String, pos: String, forms: [String]) {
    let lemma = lemma.lowercased()
    let key = "\(lemma)|\(pos)"
    if keys.insert(key).inserted { posByLemma[lemma, default: []].append(pos) }
    for form in [lemma] + forms.map({ $0.lowercased() }) where !form.contains(" ") {
        keysByForm[form, default: []].insert(key)
    }
}

let dataDir = "DanishVocab/Data"
for pack in decode([Pack].self, "\(dataDir)/packs.json") {
    for file in pack.files {
        for word in decode([PackWord].self, "\(dataDir)/\(file)") {
            var lemma = word.danish.lowercased()
            if word.partOfSpeech == "verb", lemma.hasPrefix("at ") { lemma.removeFirst(3) }
            add(lemma: lemma, pos: word.partOfSpeech,
                forms: [word.plural, word.neuter, word.present, word.past].compactMap { $0 })
        }
    }
}
for entry in decode([DictEntry].self, "\(dataDir)/dictionary.json") {
    add(lemma: entry.w, pos: entry.p, forms: entry.f.map { Array($0.values) } ?? [])
}

/// The key for a headword the sentence writer listed: exact match first, then the same word
/// under another part of speech ("med" as adverb → preposition), then an inflected form ("sent" → "sen").
func resolve(_ word: String, _ pos: String) -> String? {
    let lemma = word.lowercased()
    if keys.contains("\(lemma)|\(pos)") { return "\(lemma)|\(pos)" }
    if let known = posByLemma[lemma] {
        return "\(lemma)|\(known.first { group($0) == group(pos) } ?? known[0])"
    }
    let candidates = keysByForm[lemma] ?? []
    return candidates.first { $0.hasSuffix("|\(pos)") } ?? (candidates.count == 1 ? candidates.first : nil)
}

func tokens(_ text: String) -> [String] {
    text.lowercased().components(separatedBy: CharacterSet.letters.union(CharacterSet(charactersIn: "-")).inverted)
        .filter { !$0.isEmpty }
}

/// Unambiguous words in a sentence: a form that could be two words ("have": garden or to have) is skipped.
func links(in text: String) -> [String] {
    tokens(text).compactMap { token in
        guard let candidates = keysByForm[token] else { return nil }
        let lemmas = Set(candidates.map { $0.split(separator: "|")[0] })
        return lemmas.count == 1 && candidates.count == 1 ? candidates.first : nil
    }
}

func unique(_ items: [String]) -> [String] {
    var seen = Set<String>()
    return items.filter { seen.insert($0).inserted }
}

// MARK: - Build

var sentences: [OutSentence] = []
var unresolved: [String: Int] = [:]

let situations = decode(Situations.self, "scripts/sentences/situations.json").categories
for situation in situations {
    for (index, sentence) in situation.sentences.enumerated() {
        let linked = sentence.words.compactMap { word -> String? in
            guard let key = resolve(word.w, word.p) else { unresolved[word.w.lowercased(), default: 0] += 1; return nil }
            return key
        }
        sentences.append(OutSentence(
            id: String(format: "%@.%02d", situation.id, index + 1), da: sentence.da, en: sentence.en,
            c: situation.id, who: sentence.who, k: unique(linked)))
    }
}

var missingTarget: [String] = []
var unknownTarget: [String] = []
for sentence in decode([WordSentence].self, "scripts/sentences/words.json") {
    guard keys.contains(sentence.id.lowercased()) else { unknownTarget.append(sentence.id); continue }
    let target = sentence.id.lowercased()
    // The target should appear in some form; compounds and irregular forms are only reported.
    let lemma = String(target.split(separator: "|")[0])
    let words = tokens(sentence.da)
    let found = words.contains { keysByForm[$0]?.contains(target) == true || $0.hasPrefix(String(lemma.prefix(4))) }
        || sentence.da.lowercased().contains(lemma)
    if !found { missingTarget.append("\(sentence.id): \(sentence.da)") }
    sentences.append(OutSentence(
        id: "w.\(sentence.id)", da: sentence.da, en: sentence.en,
        t: target, k: unique([target] + links(in: sentence.da))))
}

// MARK: - Write

let output = Output(
    categories: situations.map { OutCategory(id: $0.id, title: $0.title, emoji: $0.emoji) },
    sentences: sentences)
let encoder = JSONEncoder()
encoder.outputFormatting = [.withoutEscapingSlashes]
let data = try encoder.encode(output)
let url = URL(fileURLWithPath: "\(dataDir)/sentences.json")
try data.write(to: url)

let linkCount = sentences.reduce(0) { $0 + $1.k.count }
print("\(sentences.count) sentences (\(sentences.filter { $0.c != nil }.count) in \(situations.count) situations), \(linkCount) word links")
print("words with sentences: \(Set(sentences.flatMap(\.k)).count) of \(keys.count)")
if !unresolved.isEmpty {
    print("situation words not in the dictionary (\(unresolved.count)): \(unresolved.keys.sorted().joined(separator: ", "))")
}
if !unknownTarget.isEmpty { print("unknown target words (\(unknownTarget.count)): \(unknownTarget.prefix(20).joined(separator: ", "))") }
if !missingTarget.isEmpty {
    print("target word not found in sentence (\(missingTarget.count)):")
    for line in missingTarget.prefix(40) { print("  \(line)") }
}
print("wrote \(url.path) (\(data.count / 1024) KB)")
