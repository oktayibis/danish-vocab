import Foundation

// Generates a recorded pronunciation for every word with the ElevenLabs API and saves it as
// DanishVocab/Audio/<word id>.mp3. The app plays these clips and falls back to the device voice
// for words without one. Existing files are skipped, so the script can be stopped and re-run.
//
// Run from the repository root:
//   swift scripts/generate_audio.swift --list-voices
//   swift scripts/generate_audio.swift --dry-run
//   swift scripts/generate_audio.swift --limit 10            # try a few words first
//   swift scripts/generate_audio.swift --pack beginner
//   swift scripts/generate_audio.swift                       # everything
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

    /// Same rule as Word.displayDanish in the app: "et æble", "kød", "at spise".
    var spokenText: String {
        if partOfSpeech == "noun", let article, plural != nil { "\(article) \(danish)" } else { danish }
    }
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

// MARK: - Words

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

try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
func outputURL(_ entry: Entry) -> URL { audioDir.appendingPathComponent("\(entry.id).mp3") }

let missing = entries.filter { !FileManager.default.fileExists(atPath: outputURL($0).path) }
var todo = missing
if let limit = option("--limit").flatMap(Int.init) { todo = Array(todo.prefix(limit)) }

let characters = todo.reduce(0) { $0 + $1.spokenText.count }
print("\(entries.count) words selected, \(entries.count - missing.count) already recorded, \(todo.count) to generate (\(characters) characters).")
if arguments.contains("--dry-run") || todo.isEmpty { exit(0) }

// MARK: - Generate

guard let apiKey = loadAPIKey() else { fail("set ELEVENLABS_API_KEY") }
guard let voiceId = environment["ELEVENLABS_VOICE_ID"] else { fail("set ELEVENLABS_VOICE_ID (see --list-voices)") }
let model = environment["ELEVENLABS_MODEL"] ?? "eleven_turbo_v2_5"

func synthesize(_ entry: Entry) async throws {
    var components = URLComponents(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceId)")!
    components.queryItems = [URLQueryItem(name: "output_format", value: "mp3_22050_32")]
    var request = URLRequest(url: components.url!)
    request.httpMethod = "POST"
    request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

    var body: [String: Any] = [
        "text": entry.spokenText,
        "model_id": model,
        "voice_settings": ["stability": 0.6, "similarity_boost": 0.75],
    ]
    if !model.hasPrefix("eleven_multilingual") { body["language_code"] = "da" }
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    for attempt in 1...5 {
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 200 {
            try data.write(to: outputURL(entry))
            return
        }
        // Rate limited, busy, or the library voice is still being added on first use: back off and retry.
        if status == 429 || status == 409 || status >= 500, attempt < 5 {
            try await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
            continue
        }
        throw NSError(domain: "ElevenLabs", code: status,
                      userInfo: [NSLocalizedDescriptionKey: "\(entry.id) (\(entry.spokenText)): HTTP \(status) \(String(decoding: data, as: UTF8.self))"])
    }
}

// A few requests at a time keeps us inside the concurrency limit of the smaller plans.
let concurrency = 3
var done = 0
var failures: [String] = []
try await withThrowingTaskGroup(of: (String, Error?).self) { group in
    var iterator = todo.makeIterator()
    func addNext() {
        guard let entry = iterator.next() else { return }
        group.addTask {
            do { try await synthesize(entry); return (entry.id, nil) } catch { return (entry.id, error) }
        }
    }
    for _ in 0..<concurrency { addNext() }
    while let (id, error) = try await group.next() {
        done += 1
        if let error {
            failures.append(error.localizedDescription)
            // A bad key or exhausted quota will fail every request, so stop early.
            if (error as NSError).code == 401 || failures.count >= 5 { group.cancelAll(); break }
        } else if done % 25 == 0 || done == todo.count {
            print("\(done)/\(todo.count) – last: \(id)")
        }
        addNext()
    }
}

if failures.isEmpty {
    print("Done. Rebuild the app to bundle the new clips.")
} else {
    failures.forEach { print("failed: \($0)") }
    fail("\(failures.count) word(s) failed; run the script again to retry the rest.")
}
