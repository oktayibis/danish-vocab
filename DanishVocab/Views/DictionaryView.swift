import SwiftData
import SwiftUI

struct DictionaryView: View {
    @Query private var progress: [WordProgress]
    @State private var query = ""
    @State private var scope: DictionaryScope = .all

    private let repository = WordRepository.shared

    private var learnedIds: Set<String> { Set(progress.filter(\.isLearned).map(\.wordId)) }

    private var scopedWords: [Word] {
        repository.allWords.filter { scope.group == nil || $0.partOfSpeech.group == scope.group }
    }

    private var results: [Word] { DictionarySearch.search(query, in: scopedWords) }

    /// Alphabetical sections, used when nothing has been typed.
    private var sections: [(letter: String, words: [Word])] {
        var sections: [(letter: String, words: [Word])] = []
        for word in DictionarySearch.sorted(scopedWords) {
            let letter = DictionarySearch.indexLetter(for: word)
            if sections.last?.letter == letter {
                sections[sections.count - 1].words.append(word)
            } else {
                sections.append((letter, [word]))
            }
        }
        return sections
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    ForEach(sections, id: \.letter) { section in
                        Section(section.letter) {
                            ForEach(section.words) { row(for: $0) }
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
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Danish or English word")
            .searchScopes($scope) {
                ForEach(DictionaryScope.allCases) { Text($0.title).tag($0) }
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .navigationDestination(for: Word.self) { word in
                ScrollView { WordDetailView(word: word) }
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private func row(for word: Word) -> some View {
        NavigationLink(value: word) {
            HStack(spacing: 12) {
                WordVisualView(visual: word.visual, size: 40, tint: word.tint)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(word.displayDanish).font(.headline)
                        if learnedIds.contains(word.id) {
                            Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                        }
                    }
                    Text(word.english).font(.subheadline).foregroundStyle(.secondary)
                    if let hint = word.grammarHint {
                        Text(hint).font(.caption).foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                if let pack = repository.pack(forWordId: word.id) {
                    Text(pack.title)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                        .foregroundStyle(.secondary)
                }
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
