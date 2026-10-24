import Foundation

// Builds DanishVocab/Data/dictionary.json from open data:
//   - Danish entries of English Wiktionary, as extracted by kaikki.org (CC BY-SA 4.0 / GFDL)
//     https://kaikki.org/dictionary/Danish/kaikki.org-dictionary-Danish.jsonl
//   - FrequencyWords (OpenSubtitles 2018) Danish list, used only to rank entries by frequency
//     https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/da/da_50k.txt
//
// Run from the repository root:
//   swift scripts/import_dictionary.swift <kaikki-danish.jsonl> <da_50k.txt>

// MARK: - Wiktionary input

struct KLink: Decodable { let word: String? }
struct KForm: Decodable { let form: String; let tags: [String]? }
struct KSound: Decodable { let ipa: String? }
struct KHead: Decodable { let args: [String: String]? }
struct KSense: Decodable {
    let glosses: [String]?
    let tags: [String]?
    let synonyms: [KLink]?
    let antonyms: [KLink]?
    let form_of: [KLink]?
    let alt_of: [KLink]?
}
struct KEntry: Decodable {
    let word: String
    let pos: String
    let forms: [KForm]?
    let senses: [KSense]?
    let sounds: [KSound]?
    let synonyms: [KLink]?
    let antonyms: [KLink]?
    let head_templates: [KHead]?
}

// MARK: - Output (short keys keep the bundled file small)

struct OutEntry: Encodable {
    var w: String                 // word
    var p: String                 // part of speech, same names as the app's PartOfSpeech
    var g: String?                // "en" / "et" for nouns
    var m: [String]               // English meanings
    var f: [String: String]?      // inflected forms
    var ipa: String?
    var syn: [String]?
    var ant: [String]?
    var r: Int?                   // frequency rank (1 = most frequent)
}

let posMap = [
    "noun": "noun", "verb": "verb", "adj": "adjective", "adv": "adverb", "prep": "preposition",
    "pron": "pronoun", "det": "pronoun", "conj": "conjunction", "num": "number", "intj": "interjection",
    "phrase": "phrase", "proverb": "proverb", "prep_phrase": "phrase", "contraction": "phrase",
]

let args = CommandLine.arguments.dropFirst()
guard args.count == 2 else {
    print("usage: swift scripts/import_dictionary.swift <kaikki-danish.jsonl> <da_50k.txt>")
    exit(1)
}
let wiktionaryPath = args[args.startIndex]
let frequencyPath = args[args.index(after: args.startIndex)]
let output = URL(fileURLWithPath: "DanishVocab/Data/dictionary.json")

func tags(_ form: KForm) -> Set<String> { Set(form.tags ?? []) }
func pick(_ forms: [KForm], has: Set<String>, not excluded: Set<String> = []) -> String? {
    forms.first { has.isSubset(of: tags($0)) && tags($0).isDisjoint(with: excluded) && $0.form != "-" }?.form
}

func inflections(pos: String, forms: [KForm], word: String) -> [String: String]? {
    var result: [String: String] = [:]
    switch pos {
    case "noun":
        result["definite"] = pick(forms, has: ["definite", "singular"], not: ["genitive"])
        result["plural"] = pick(forms, has: ["indefinite", "plural"], not: ["genitive"])
        result["definitePlural"] = pick(forms, has: ["definite", "plural"], not: ["genitive"])
    case "verb":
        result["present"] = pick(forms, has: ["present"], not: ["passive", "participle"])
        result["past"] = pick(forms, has: ["past"], not: ["passive", "participle"])
        // Some tables list the bare auxiliary ("er", "har") as the perfect: use the participle then.
        let perfect = forms.filter { !["er", "har"].contains($0.form) }
        result["perfect"] = pick(perfect, has: ["perfect"]) ?? pick(perfect, has: ["participle", "past"])
        result["imperative"] = pick(forms, has: ["imperative"], not: ["passive"])
    case "adjective":
        result["neuter"] = pick(forms, has: ["neuter"], not: ["error-unrecognized-form"])
        result["plural"] = pick(forms, has: ["plural"], not: ["comparative", "superlative", "error-unrecognized-form"])
        result["comparative"] = pick(forms, has: ["comparative"], not: ["error-unrecognized-form"])
        result["superlative"] = pick(forms, has: ["superlative", "predicative"]) ?? pick(forms, has: ["superlative"])
    default:
        break
    }
    // Keep forms equal to the word only where that is itself informative (glad → glad, et hus → huse).
    result = result.filter { !$0.value.isEmpty && ($0.value != word || ["plural", "neuter"].contains($0.key)) }
    return result.isEmpty ? nil : result
}

/// First occurrence of each string, in order (NSOrderedSet does not dedupe reliably on Linux).
func unique(_ items: [String]) -> [String] {
    var seen = Set<String>()
    return items.filter { seen.insert($0).inserted }
}

func gender(_ entry: KEntry, senses: [KSense]) -> String? {
    let senseTags = Set(senses.flatMap { $0.tags ?? [] })
    if senseTags.contains("common") && !senseTags.contains("neuter") { return "en" }
    if senseTags.contains("neuter") && !senseTags.contains("common") { return "et" }
    switch entry.head_templates?.first?.args?["g"] {
    case "c": return "en"
    case "n": return "et"
    default: return nil
    }
}

func clean(_ gloss: String) -> String? {
    let text = gloss.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, text.count <= 140 else { return nil }
    return text
}

// MARK: - Read Wiktionary

var merged: [String: OutEntry] = [:]          // "word|pos" → entry
var order: [String] = []
var formOf: [String: String] = [:]            // lowercased form → lowercased lemma, from Wiktionary's "form of" entries
var tableForm: [String: String] = [:]         // lowercased form → lowercased lemma, from inflection tables
var skipped = 0

guard let reader = FileHandle(forReadingAtPath: wiktionaryPath) else { fatalError("cannot open \(wiktionaryPath)") }
let decoder = JSONDecoder()
var buffer = Data()
func handle(line: Data) {
    guard let entry = try? decoder.decode(KEntry.self, from: line) else { skipped += 1; return }
    let senses = entry.senses ?? []
    // Inflected forms point at their lemma: useful for ranking, not as entries of their own.
    for sense in senses {
        for target in (sense.form_of ?? []) + (sense.alt_of ?? []) {
            if let lemma = target.word { formOf[entry.word.lowercased()] = formOf[entry.word.lowercased()] ?? lemma.lowercased() }
        }
    }
    guard let pos = posMap[entry.pos] else { return }
    let real = senses.filter { sense in
        let t = Set(sense.tags ?? [])
        return t.isDisjoint(with: ["form-of", "alt-of"]) && !(sense.glosses ?? []).isEmpty
    }
    guard !real.isEmpty else { return }

    let meanings = real.compactMap { $0.glosses?.last.flatMap(clean) }
    guard !meanings.isEmpty else { return }
    let forms = entry.forms ?? []
    for form in forms where !tags(form).contains("table-tags") && !tags(form).contains("inflection-template") {
        // Bare auxiliaries ("er", "har") and multi-word forms say nothing about the lemma.
        let key = form.form.lowercased()
        guard !key.contains(" "), !["er", "har"].contains(key), key != entry.word.lowercased() else { continue }
        if tableForm[key] == nil { tableForm[key] = entry.word.lowercased() }
    }
    let synonyms = ((entry.synonyms ?? []) + real.flatMap { $0.synonyms ?? [] }).compactMap(\.word)
    let antonyms = ((entry.antonyms ?? []) + real.flatMap { $0.antonyms ?? [] }).compactMap(\.word)

    let key = "\(entry.word)|\(pos)"
    if var existing = merged[key] {
        // Same word and part of speech under another etymology: add its meanings.
        existing.m = unique(existing.m + meanings)
        existing.syn = (existing.syn ?? []) + synonyms
        existing.ant = (existing.ant ?? []) + antonyms
        merged[key] = existing
        return
    }
    order.append(key)
    merged[key] = OutEntry(
        w: entry.word,
        p: pos,
        g: pos == "noun" ? gender(entry, senses: real) : nil,
        m: meanings,
        f: inflections(pos: pos, forms: forms, word: entry.word),
        ipa: entry.sounds?.compactMap(\.ipa).first,
        syn: synonyms,
        ant: antonyms,
        r: nil)
}
while true {
    let chunk = reader.readData(ofLength: 1 << 20)
    if chunk.isEmpty { break }
    buffer.append(chunk)
    while let newline = buffer.firstIndex(of: 0x0A) {
        handle(line: buffer.subdata(in: buffer.startIndex..<newline))
        buffer.removeSubrange(buffer.startIndex...newline)
    }
}
if !buffer.isEmpty { handle(line: buffer) }

// MARK: - Rank by frequency

let lemmaKeys = Dictionary(grouping: order, by: { $0.split(separator: "|")[0].lowercased() })
var rank = 0
var rankedKeys = Set<String>()
var shadowed: [String] = []                   // nouns spelled like a form of another word, ranked last
func rankKeys(_ keys: [String]) {
    let fresh = keys.filter { !rankedKeys.contains($0) }
    guard !fresh.isEmpty else { return }
    rank += 1
    for key in fresh { merged[key]?.r = rank; rankedKeys.insert(key) }
}
for line in try String(contentsOfFile: frequencyPath, encoding: .utf8).split(separator: "\n") {
    guard let form = line.split(separator: " ").first.map({ String($0).lowercased() }) else { continue }
    if let base = formOf[form] ?? tableForm[form], base != form, let baseKeys = lemmaKeys[base] {
        // "galt" is mostly gal's neuter, not the noun (a hog): credit gal, keep the noun for later.
        // Pronouns and the like ("det", "mig") are forms too, but common in their own right.
        let own = lemmaKeys[form] ?? []
        let isShadowed = { (key: String) in key.hasSuffix("|noun") || key.hasSuffix("|verb") }
        shadowed += own.filter(isShadowed)
        rankKeys(baseKeys + own.filter { !isShadowed($0) })
    } else if let keys = lemmaKeys[form] {
        rankKeys(keys)
    } else if let lemma = tableForm[form], let keys = lemmaKeys[lemma] {
        rankKeys(keys)
    }
}
for key in shadowed { rankKeys([key]) }

// MARK: - Write

func tidy(_ words: [String]?, excluding word: String) -> [String]? {
    let list = unique(words ?? []).filter { $0 != word && !$0.isEmpty }
    return list.isEmpty ? nil : Array(list.prefix(8))
}
var entries = order.compactMap { merged[$0] }
for i in entries.indices {
    entries[i].m = Array(unique(entries[i].m).prefix(6))
    entries[i].syn = tidy(entries[i].syn, excluding: entries[i].w)
    entries[i].ant = tidy(entries[i].ant, excluding: entries[i].w)
}
// Most frequent first, the rest alphabetically.
entries.sort { a, b in
    switch (a.r, b.r) {
    case let (x?, y?): return x < y
    case (_?, nil): return true
    case (nil, _?): return false
    default: return a.w.compare(b.w, locale: Locale(identifier: "da_DK")) == .orderedAscending
    }
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.withoutEscapingSlashes]
let data = try encoder.encode(entries)
try data.write(to: output)

let counts = Dictionary(grouping: entries, by: \.p).mapValues(\.count).sorted { $0.value > $1.value }
print("\(entries.count) entries (\(rankedKeys.count) ranked by frequency), \(skipped) lines skipped")
print("by part of speech: \(counts.map { "\($0.key) \($0.value)" }.joined(separator: ", "))")
print("with synonyms: \(entries.filter { $0.syn != nil }.count), antonyms: \(entries.filter { $0.ant != nil }.count)")
print("wrote \(output.path) (\(data.count / 1024) KB)")
