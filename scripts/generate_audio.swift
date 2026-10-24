import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking // URLSession on Linux
#endif

// Records pronunciations with the ElevenLabs API and saves them in DanishVocab/Audio:
//   <word id>.mp3      the word itself ("et æble", "at spise")
//   <word id>-ex.mp3   its example sentence (with --examples)
//   <sentence id>.mp3  a practical sentence from Data/sentences.json, e.g. cafe.01.mp3 (with --situations)
// The app plays these clips and falls back to the device voice when one is missing.
//
// scripts/audio_manifest.json remembers which text each clip was made from, so a clip is re-recorded
// when its word or sentence changes. Up-to-date clips are skipped, so the script can be
// stopped and re-run at any time.
//
// Run from the repository root:
//   swift scripts/generate_audio.swift --list-voices
//   swift scripts/generate_audio.swift --dry-run [--examples]
//   swift scripts/generate_audio.swift --limit 10            # try a few first
//   swift scripts/generate_audio.swift --pack beginner
//   swift scripts/generate_audio.swift                       # all words
//   swift scripts/generate_audio.swift --examples            # all example sentences
//   swift scripts/generate_audio.swift --situations [--category cafe]   # practical sentences
//
// Environment:
//   ELEVENLABS_API_KEY   required, or ELEVENLABS_API_KEY=... in ~/.config/elevenlabs-mcp/.env
//                        (the same file the ElevenLabs MCP server reads)
//   ELEVENLABS_VOICE_ID  required (except for --list-voices / --dry-run)
//   ELEVENLABS_MODEL     optional, default eleven_turbo_v2_5. Turbo/Flash models accept
//                        language_code "da", which stops short words like "to" or "fire"
//                        being read as English.

struct Pack: Decodable { let id: String; let files: [String] }

struct Entry: Decodable {
    let id: String
    let danish: String
    let article: String?
    let plural: String?
    let partOfSpeech: String
    let exampleDa: String

    /// Same rule as Word.displayDanish in the app: "et æble", "kød", "at spise".
    var displayDanish: String {
        if partOfSpeech == "noun", let article, plural != nil { "\(article) \(danish)" } else { danish }
    }
}

/// A sentence from Data/sentences.json; only the situation ones (with a category) are recorded.
struct PoolSentence: Decodable { let id: String; let da: String; let c: String? }
struct Pool: Decodable { let sentences: [PoolSentence] }

/// One clip to record.
struct Clip {
    let name: String
    let text: String
}

let arguments = CommandLine.arguments.dropFirst()
func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), arguments.index(after: index) < arguments.endIndex else { return nil }
    return arguments[arguments.index(after: index)]
}
let environment = ProcessInfo.processInfo.environment

/// The API key from the environment, or from the ElevenLabs MCP server's config file.
func loadAPIKey() -> String? {
    if let key = environment["ELEVENLABS_API_KEY"], !key.isEmpty { return key }
    let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/elevenlabs-mcp/.env")
    guard let contents = try? String(contentsOf: file, encoding: .utf8) else { return nil }
    for line in contents.split(separator: "\n") where line.hasPrefix("ELEVENLABS_API_KEY=") {
        return line.dropFirst("ELEVENLABS_API_KEY=".count)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"' \r"))
    }
    return nil
}
let dataDir = URL(fileURLWithPath: "DanishVocab/Data")
let audioDir = URL(fileURLWithPath: "DanishVocab/Audio")
let manifestURL = URL(fileURLWithPath: "scripts/audio_manifest.json")

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

// MARK: - Voices

if arguments.contains("--list-voices") {
    guard let key = loadAPIKey() else { fail("set ELEVENLABS_API_KEY") }
    var request = URLRequest(url: URL(string: "https://api.elevenlabs.io/v1/voices")!)
    request.setValue(key, forHTTPHeaderField: "xi-api-key")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { fail(String(decoding: data, as: UTF8.self)) }
    struct Voices: Decodable {
        struct Voice: Decodable { let voice_id: String; let name: String; let labels: [String: String]? }
        let voices: [Voice]
    }
    for voice in try JSONDecoder().decode(Voices.self, from: data).voices {
        let labels = (voice.labels ?? [:]).sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        print("\(voice.voice_id)  \(voice.name)  \(labels)")
    }
    exit(0)
}

// MARK: - What to record

guard FileManager.default.fileExists(atPath: dataDir.path) else { fail("run this from the repository root") }
let packs = try JSONDecoder().decode([Pack].self, from: Data(contentsOf: dataDir.appendingPathComponent("packs.json")))
let selectedPacks = option("--pack").map { name in packs.filter { $0.id == name } } ?? packs
guard !selectedPacks.isEmpty else { fail("unknown pack \(option("--pack") ?? "")") }

var entries: [Entry] = []
for pack in selectedPacks {
    for file in pack.files {
        entries += try JSONDecoder().decode([Entry].self, from: Data(contentsOf: dataDir.appendingPathComponent(file)))
    }
}

let recordExamples = arguments.contains("--examples")
let recordSituations = arguments.contains("--situations")
let clips: [Clip]
if recordSituations {
    let pool = try JSONDecoder().decode(Pool.self, from: Data(contentsOf: dataDir.appendingPathComponent("sentences.json")))
    let category = option("--category")
    clips = pool.sentences
        .filter { $0.c != nil && (category == nil || $0.c == category) }
        .map { Clip(name: $0.id, text: $0.da) }
    guard !clips.isEmpty else { fail("no situation sentences\(category.map { " in \($0)" } ?? "")") }
} else {
    clips = entries.map { entry in
        recordExamples ? Clip(name: "\(entry.id)-ex", text: entry.exampleDa) : Clip(name: entry.id, text: entry.displayDanish)
    }
}

try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
func fileURL(_ clip: Clip) -> URL { audioDir.appendingPathComponent("\(clip.name).mp3") }
func exists(_ clip: Clip) -> Bool { FileManager.default.fileExists(atPath: fileURL(clip).path) }

/// clip name → the text it was recorded from.
var manifest = (try? JSONDecoder().decode([String: String].self, from: Data(contentsOf: manifestURL))) ?? [:]
func saveManifest() throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(manifest).write(to: manifestURL)
}

// Clips recorded before the manifest existed are trusted as they are.
for clip in clips where exists(clip) && manifest[clip.name] == nil { manifest[clip.name] = clip.text }
try saveManifest()

let missing = clips.filter { !exists($0) || manifest[$0.name] != $0.text }
var todo = missing
if let limit = option("--limit").flatMap(Int.init) { todo = Array(todo.prefix(limit)) }

let characters = todo.reduce(0) { $0 + $1.text.count }
let kind = recordSituations ? "situation sentences" : recordExamples ? "example sentences" : "words"
print("\(clips.count) \(kind) selected, \(clips.count - missing.count) up to date, \(todo.count) to record (\(characters) characters).")
if arguments.contains("--dry-run") || todo.isEmpty { exit(0) }

// MARK: - Record

guard let apiKey = loadAPIKey() else { fail("set ELEVENLABS_API_KEY") }
guard let voiceId = environment["ELEVENLABS_VOICE_ID"] else { fail("set ELEVENLABS_VOICE_ID (see --list-voices)") }
let model = environment["ELEVENLABS_MODEL"] ?? "eleven_turbo_v2_5"

func synthesize(_ clip: Clip) async throws {
    var components = URLComponents(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceId)")!
    components.queryItems = [URLQueryItem(name: "output_format", value: "mp3_22050_32")]
    var request = URLRequest(url: components.url!)
    request.httpMethod = "POST"
    request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

    var body: [String: Any] = [
        "text": clip.text,
        "model_id": model,
        "voice_settings": ["stability": 0.6, "similarity_boost": 0.75],
    ]
    if !model.hasPrefix("eleven_multilingual") { body["language_code"] = "da" }
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    for attempt in 1...5 {
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 200 {
            try data.write(to: fileURL(clip))
            return
        }
        // Rate limited, busy, or the library voice is still being added on first use: back off and retry.
        if status == 429 || status == 409 || status >= 500, attempt < 5 {
            try await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
            continue
        }
        throw NSError(domain: "ElevenLabs", code: status,
                      userInfo: [NSLocalizedDescriptionKey: "\(clip.name) (\(clip.text)): HTTP \(status) \(String(decoding: data, as: UTF8.self))"])
    }
}

// A few requests at a time keeps us inside the concurrency limit of the smaller plans.
let concurrency = 3
var done = 0
var failures: [String] = []
try await withThrowingTaskGroup(of: (Clip, Error?).self) { group in
    var iterator = todo.makeIterator()
    func addNext() {
        guard let clip = iterator.next() else { return }
        group.addTask {
            do { try await synthesize(clip); return (clip, nil) } catch { return (clip, error) }
        }
    }
    for _ in 0..<concurrency { addNext() }
    while let (clip, error) = try await group.next() {
        done += 1
        if let error {
            failures.append(error.localizedDescription)
            // A bad key or exhausted quota will fail every request, so stop early.
            if (error as NSError).code == 401 || failures.count >= 5 { group.cancelAll(); break }
        } else {
            manifest[clip.name] = clip.text
            if done % 25 == 0 || done == todo.count {
                try saveManifest()
                print("\(done)/\(todo.count) – last: \(clip.name)")
            }
        }
        addNext()
    }
}
try saveManifest()

if failures.isEmpty {
    print("Done. Rebuild the app to bundle the new clips.")
} else {
    failures.forEach { print("failed: \($0)") }
    fail("\(failures.count) clip(s) failed; run the script again to retry the rest.")
}
