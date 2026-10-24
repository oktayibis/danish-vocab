import SwiftUI

/// Version, what's new, and where the words, sentences and recordings come from.
struct AboutView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    @ViewBuilder
    private func creditLinks(_ credit: Credit) -> some View {
        ForEach(credit.links, id: \.title) { link in Link(link.title, destination: link.url) }
        if let licenseURL = credit.licenseURL {
            Link("Licence: \(credit.license)", destination: licenseURL)
        } else {
            Text("Licence: \(credit.license)").foregroundStyle(.secondary)
        }
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
                        Text(credit.detail).font(.callout)
                        Text("By \(credit.author)").font(.caption).foregroundStyle(.secondary)
                        if let changes = credit.changes {
                            Text("Changes: \(changes)").font(.caption).foregroundStyle(.secondary)
                        }
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 14) { creditLinks(credit) }
                            VStack(alignment: .leading, spacing: 4) { creditLinks(credit) }
                        }
                        .font(.caption)
                        // Two links in one row: keep each tappable on its own instead of the whole row.
                        .buttonStyle(.borderless)
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

/// Where a part of the app's content comes from: who made it, its licence, and what we changed.
/// CC BY-SA asks for the author, a link to the source, a link to the licence and a note of any changes.
/// Keep this in step with ATTRIBUTION.md.
/// A titled link under a credit, e.g. "Wiktionary" or "kaikki.org".
struct CreditLink {
    let title: String
    let url: URL

    init(_ title: String, _ url: String) {
        self.title = title
        self.url = URL(string: url)!
    }
}

struct Credit: Identifiable {
    let title: String
    let detail: String
    let author: String
    /// Where the content comes from: the original source first, then tools and services in between.
    let links: [CreditLink]
    let license: String
    let licenseURL: URL?
    var changes: String? = nil

    var id: String { title }

    private static let ccBySA = URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")
    private static let mit = URL(string: "\(MistakeReport.repository)/blob/main/LICENSE")

    static let all: [Credit] = [
        Credit(title: "Dictionary",
               detail: "About 23,000 Danish words with their English meanings, forms, pronunciation (IPA), synonyms and antonyms come from English Wiktionary.",
               author: "Wiktionary contributors; extracted by kaikki.org with wiktextract (Tatu Ylonen)",
               links: [CreditLink("Wiktionary", "https://en.wiktionary.org/wiki/Wiktionary:Main_Page"),
                       CreditLink("kaikki.org", "https://kaikki.org/dictionary/Danish/"),
                       CreditLink("wiktextract", "https://github.com/tatuylonen/wiktextract"),
                       CreditLink("Wiktionary copyrights", "https://en.wiktionary.org/wiki/Wiktionary:Copyrights")],
               license: "CC BY-SA 4.0",
               licenseURL: ccBySA,
               changes: "selected and shortened meanings and forms, merged entries, added frequency ranks and 47 extra words. The resulting dictionary is shared under CC BY-SA 4.0."),
        Credit(title: "Word frequency",
               detail: "Dictionary words are ranked by how often they appear in Danish film and TV subtitles.",
               author: "Hermit Dave (FrequencyWords), from the OpenSubtitles 2018 corpus (OPUS, opensubtitles.org)",
               links: [CreditLink("FrequencyWords", "https://github.com/hermitdave/FrequencyWords"),
                       CreditLink("OpenSubtitles 2018 (OPUS)", "https://opus.nlpl.eu/legacy/OpenSubtitles-v2018.php"),
                       CreditLink("opensubtitles.org", "https://www.opensubtitles.org")],
               license: "CC BY-SA 4.0",
               licenseURL: ccBySA,
               changes: "only used to sort the dictionary; the list itself is not included."),
        Credit(title: "Extra everyday words",
               detail: "47 words Wiktionary lacks, such as Rejsekort, MitID and pantbon.",
               author: "Danish Vocab, written with Claude (Anthropic)",
               links: [CreditLink("extra_words.json", "\(MistakeReport.repository)/blob/main/scripts/extra_words.json"),
                       CreditLink("Claude", "https://www.anthropic.com/claude")],
               license: "CC BY-SA 4.0",
               licenseURL: ccBySA),
        Credit(title: "Learning words, pictures and sentences",
               detail: "The 1950 pack words, their example sentences and pictures, the 360 practical sentences and an example for every dictionary word. Sentences for the 5,000 most frequent words and the situations were written with Claude Sonnet, the rest with Claude Haiku.",
               author: "Oktay Ibis, written with Claude (Anthropic)",
               links: [CreditLink("GitHub", MistakeReport.repository),
                       CreditLink("Claude", "https://www.anthropic.com/claude")],
               license: "MIT",
               licenseURL: mit),
        Credit(title: "Pronunciation",
               detail: "Pack words and their example sentences are read by the native Danish voice \"Søren\". Other sentences are read by the Danish voice on your iPhone.",
               author: "Recorded with ElevenLabs on a paid plan; device voice by Apple",
               links: [CreditLink("ElevenLabs", "https://elevenlabs.io"),
                       CreditLink("Danish voices on iPhone", "https://support.apple.com/guide/iphone/hear-iphone-speak-the-screen-iph96b214f0/ios")],
               license: "ElevenLabs terms of service",
               licenseURL: URL(string: "https://elevenlabs.io/terms-of-use")),
        Credit(title: "App",
               detail: "The app's code, icon and drawings.",
               author: "Oktay Ibis, written with Claude (Anthropic)",
               links: [CreditLink("GitHub", MistakeReport.repository),
                       CreditLink("Claude", "https://www.anthropic.com/claude")],
               license: "MIT",
               licenseURL: mit),
    ]
}

#Preview {
    NavigationStack { AboutView() }
}
