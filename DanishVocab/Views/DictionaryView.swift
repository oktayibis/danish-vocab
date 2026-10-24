import SwiftData
import SwiftUI

struct DictionaryView: View {
    @Query private var progress: [WordProgress]
    @State private var query = ""
    @State private var scope: DictionaryScope = .all

    /// Read when the view is shown, so the dictionary loads on first use, not at app launch.
    private var index: DictionaryLookup { .shared }
    private let repository = WordRepository.shared

    private var learnedIds: Set<String> { Set(progress.filter(\.isLearned).map(\.wordId)) }
    private var results: [DictionaryItem] { index.search(query, group: scope.group) }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    ForEach(index.sections(group: scope.group), id: \.letter) { section in
                        Section(section.letter) {
                            ForEach(section.items) { row(for: $0) }
                        }
                    }
                } else {
                    ForEach(results) { row(for: $0) }
                }
            }
            .listStyle(.plain)
            .overlay {
                if !query.isEmpty && results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Dictionary")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "\(index.items.count.formatted()) Danish & English words")
            .searchScopes($scope) {
                ForEach(DictionaryScope.allCases) { Text($0.title).tag($0) }
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .navigationDestination(for: DictionaryItem.self) { item in
                switch item {
                case .word(let word):
                    ScrollView { WordDetailView(word: word) }
                        .navigationBarTitleDisplayMode(.inline)
                case .entry(let entry):
                    DictionaryEntryView(entry: entry)
                }
            }
        }
    }

    private func row(for item: DictionaryItem) -> some View {
        NavigationLink(value: item) {
            HStack(spacing: 12) {
                switch item {
                case .word(let word):
                    WordVisualView(visual: word.visual, size: 40, tint: word.tint)
                case .entry:
                    Image(systemName: "character.book.closed")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 40)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.displayDanish).font(.headline)
                        if learnedIds.contains(item.id) {
                            Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                        }
                    }
                    Text(item.english).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    if let hint = item.grammarHint {
                        Text(hint).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                    }
                }
                Spacer()
                Text(tag(for: item))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The pack a word is taught in, or its word type for dictionary-only words.
    private func tag(for item: DictionaryItem) -> String {
        if case .word(let word) = item, let pack = repository.pack(forWordId: word.id) { return pack.title }
        return item.partOfSpeech.singularTitle
    }
}

/// A word that is only in the open dictionary: meanings, forms, pronunciation and related words.
struct DictionaryEntryView: View {
    let entry: DictionaryEntry

    /// Read when the view is shown, so the dictionary loads on first use, not at app launch.
    private var index: DictionaryLookup { .shared }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text(entry.displayDanish).font(.largeTitle.bold()).minimumScaleFactor(0.6)
                        SpeakButton(text: entry.displayDanish)
                    }
                    HStack(spacing: 8) {
                        Text(entry.p.singularTitle)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.tint.opacity(0.12), in: Capsule())
                        if let gender = entry.g { Text("\(gender)-word").font(.caption).foregroundStyle(.secondary) }
                        if let ipa = entry.ipa { Text(ipa).font(.callout.monospaced()).foregroundStyle(.secondary) }
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Meaning") {
                ForEach(Array(entry.m.enumerated()), id: \.offset) { number, meaning in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(number + 1).").foregroundStyle(.secondary).monospacedDigit()
                        Text(meaning)
                    }
                }
            }

            if let forms = entry.grammarHint {
                Section("Forms") {
                    ForEach(forms.components(separatedBy: " · "), id: \.self) { line in
                        let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                        HStack {
                            Text(parts.first ?? "").foregroundStyle(.secondary)
                            Spacer()
                            Text(parts.last ?? "").bold()
                        }
                    }
                }
            }

            let sentences = SentenceStore.shared.sentences(containing: entry.w, partOfSpeech: entry.p, limit: 10)
            if !sentences.isEmpty {
                Section(sentences.count == 1 ? "Example" : "Examples") {
                    ForEach(sentences) { SentenceRow(sentence: $0) }
                }
            }

            let related = index.related(to: .entry(entry))
            relatedSection("Synonyms", words: related.synonyms, icon: "equal.circle.fill", color: .green)
            relatedSection("Antonyms", words: related.antonyms, icon: "arrow.left.arrow.right.circle.fill", color: .orange)

            Section {
                if entry.src == "app" {
                    Text("Source: Danish Vocab, CC BY-SA 4.0").font(.caption).foregroundStyle(.secondary)
                } else if let page = entry.wiktionaryURL {
                    // CC BY-SA: credit the authors and link to the original entry.
                    Link("Source: Wiktionary contributors, CC BY-SA 4.0", destination: page).font(.caption)
                }
                Link(destination: MistakeReport.url(forWord: entry.displayDanish, english: entry.m.first ?? "",
                                                    id: "dict.\(entry.w).\(entry.p.rawValue)")) {
                    Label("Report a mistake", systemImage: "exclamationmark.bubble")
                }
                .font(.caption)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func relatedSection(_ title: String, words: [String], icon: String, color: Color) -> some View {
        if !words.isEmpty {
            Section {
                ForEach(words, id: \.self) { word in
                    if let item = index.item(for: word, preferring: entry.p) {
                        NavigationLink(value: item) {
                            Label(item.displayDanish, systemImage: icon).foregroundStyle(color, .primary)
                        }
                    } else {
                        Label(word, systemImage: icon).foregroundStyle(color, .primary)
                    }
                }
            } header: {
                Text(title)
            }
        }
    }
}

enum DictionaryScope: String, CaseIterable, Identifiable {
    case all
    case nouns
    case verbs
    case adjectives
    case smallWords

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .nouns: "Nouns"
        case .verbs: "Verbs"
        case .adjectives: "Adjectives"
        // Five scopes share one bar, so keep this short.
        case .smallWords: "Small"
        }
    }

    var group: WordGroup? { WordGroup(rawValue: rawValue) }
}

#Preview {
    DictionaryView().modelContainer(for: [WordProgress.self, PlayerStats.self, EarnedBadge.self], inMemory: true)
}
