import SwiftUI

/// Practical sentences for everyday situations: the café, the doctor, the kommune…
struct PhrasesView: View {
    /// Read when the view is shown, so the sentences load on first use, not at app launch.
    private var store: SentenceStore { .shared }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.categories) { category in
                        NavigationLink(value: category) {
                            HStack(spacing: 14) {
                                Text(category.emoji).font(.largeTitle)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.title).font(.headline)
                                    Text("\(store.sentences(in: category.id).count) sentences")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } footer: {
                    Text("Sentences you will say and hear in Denmark. Tap one to hear it.")
                }
            }
            .navigationTitle("Phrases")
            .navigationDestination(for: SentenceCategory.self) { PhraseCategoryView(category: $0) }
        }
    }
}

struct PhraseCategoryView: View {
    let category: SentenceCategory

    @State private var filter: PhraseFilter = .all
    @State private var showsEnglish = true

    private var sentences: [Sentence] {
        SentenceStore.shared.sentences(in: category.id).filter { sentence in
            switch filter {
            case .all: true
            case .say: !sentence.isHeard
            case .hear: sentence.isHeard
            }
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Show", selection: $filter) {
                    ForEach(PhraseFilter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            Section {
                ForEach(sentences) { SentenceRow(sentence: $0, showsEnglish: showsEnglish) }
            } footer: {
                Text("Hide the English to test yourself. Long-press a sentence to report a mistake.")
            }
        }
        .navigationTitle("\(category.emoji) \(category.title)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsEnglish.toggle()
                } label: {
                    Label(showsEnglish ? "Hide English" : "Show English", systemImage: showsEnglish ? "eye" : "eye.slash")
                }
            }
        }
    }
}

enum PhraseFilter: String, CaseIterable, Identifiable {
    case all
    case say
    case hear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .say: "You say"
        case .hear: "You hear"
        }
    }
}

/// One sentence: Danish, English underneath, tap to hear it, long-press to report a mistake.
struct SentenceRow: View {
    let sentence: Sentence
    var showsEnglish = true

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            SpeechService.shared.speak(sentence)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if let who = sentence.who {
                    Image(systemName: who == "them" ? "ear" : "person.wave.2")
                        .foregroundStyle(who == "them" ? Color.orange : Color.accentColor)
                        .frame(width: 22)
                        .accessibilityLabel(who == "them" ? "You hear" : "You say")
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(sentence.da).font(.body.weight(.medium))
                    if showsEnglish {
                        Text(sentence.en).font(.callout).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "speaker.wave.2.fill")
                    .font(.callout)
                    .foregroundStyle(.tint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Report a mistake", systemImage: "exclamationmark.bubble") {
                openURL(MistakeReport.url(for: sentence))
            }
        }
    }
}

#Preview {
    PhrasesView()
}
