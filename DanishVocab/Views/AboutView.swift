import SwiftUI

/// Version, what's new, and where the words, sentences and recordings come from.
struct AboutView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 6) {
                    Text("🇩🇰").font(.system(size: 56))
                    Text("Danish Vocab").font(.title2.bold())
                    Text(version).font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("What's new") {
                ForEach(Release.all) { release in
                    DisclosureGroup {
                        ForEach(release.notes, id: \.self) { Text($0).font(.callout) }
                    } label: {
                        HStack {
                            Text("Version \(release.version)").font(.headline)
                            Spacer()
                            Text(release.date).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                ForEach(Credit.all) { credit in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(credit.title).font(.headline)
                        Text(credit.detail).font(.callout).foregroundStyle(.secondary)
                        if let url = credit.url {
                            Link(credit.license, destination: url).font(.caption)
                        } else {
                            Text(credit.license).font(.caption).foregroundStyle(.tint)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Sources & licences")
            } footer: {
                Text("The word lists and sentences were written with AI and checked automatically, not yet by a native speaker. Please report anything that looks wrong.")
            }

            Section {
                Link(destination: URL(string: "\(MistakeReport.repository)/issues/new")!) {
                    Label("Report a mistake or suggest a word", systemImage: "exclamationmark.bubble")
                }
                Link(destination: URL(string: MistakeReport.repository)!) {
                    Label("Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One entry under "What's new". Add the newest release at the top when bumping MARKETING_VERSION in project.yml.
struct Release: Identifiable {
    let version: String
    let date: String
    let notes: [String]

    var id: String { version }

    static let all: [Release] = [
        Release(version: "1.0", date: "October 2026", notes: [
            "1950 words in four packs, with pictures, flashcards, quizzes and spaced repetition.",
            "Every pack word and its example sentence recorded by a native Danish voice.",
            "A dictionary of about 25,000 words with meanings, forms and synonyms.",
            "Phrases: 360 practical sentences for 12 everyday situations.",
            "Every word shows the sentences it appears in.",
            "Report a mistake from any sentence or word.",
        ]),
    ]
}

/// Where a part of the app's content comes from, and its licence.
struct Credit: Identifiable {
    let title: String
    let detail: String
    let license: String
    let url: URL?

    var id: String { title }

    static let all: [Credit] = [
        Credit(title: "Learning words and pictures",
               detail: "The 1950 pack words, their example sentences, emoji choices and drawings were made for this app with Claude (Anthropic).",
               license: "MIT licence, © 2026 Oktay Ibis",
               url: URL(string: "\(MistakeReport.repository)/blob/main/LICENSE")),
        Credit(title: "Dictionary",
               detail: "About 23,000 words with meanings, forms, pronunciation (IPA) and synonyms, from the Danish entries of English Wiktionary, via kaikki.org.",
               license: "Wiktionary, CC BY-SA 4.0",
               url: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")),
        Credit(title: "Extra everyday words",
               detail: "47 words Wiktionary lacks, such as Rejsekort, MitID and pantbon, written for this app.",
               license: "Danish Vocab, CC BY-SA 4.0",
               url: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")),
        Credit(title: "Word frequency",
               detail: "Words are ranked by how often they appear in Danish film and TV subtitles: FrequencyWords by Hermit Dave, built from OpenSubtitles 2018.",
               license: "FrequencyWords, CC BY-SA 4.0",
               url: URL(string: "https://github.com/hermitdave/FrequencyWords")),
        Credit(title: "Sentences",
               detail: "The practical sentences and one example for every dictionary word were written with Claude (Anthropic): Sonnet for the situations and the 5,000 most frequent words, Haiku for the rest.",
               license: "Part of Danish Vocab, MIT licence",
               url: nil),
        Credit(title: "Pronunciation",
               detail: "Pack words and their example sentences are read by the native Danish voice \"Søren\", generated with ElevenLabs on a paid plan. Other sentences are read by the Danish voice on your iPhone.",
               license: "ElevenLabs",
               url: URL(string: "https://elevenlabs.io")),
    ]
}

#Preview {
    NavigationStack { AboutView() }
}
