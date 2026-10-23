import SwiftData
import SwiftUI

struct PackView: View {
    let pack: WordPack

    @Environment(\.modelContext) private var modelContext
    @Query private var progress: [WordProgress]
    @State private var group: WordGroup = .nouns
    @State private var category: String?
    @State private var selectedWord: Word?
    @State private var practice: PracticeRequest?

    private let repository = WordRepository.shared

    private var groups: [WordGroup] {
        WordGroup.allCases.filter { !repository.words(inPack: pack.id, group: $0).isEmpty }
    }
    private var categories: [String] { repository.categories(inPack: pack.id, group: group) }
    private var words: [Word] { repository.words(inPack: pack.id, group: group, category: category) }
    private var boxes: [String: Int] { Dictionary(progress.map { ($0.wordId, $0.box) }, uniquingKeysWith: max) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Word type", selection: $group) {
                    ForEach(groups) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: group) { category = nil }

                categoryChips

                HStack(spacing: 12) {
                    practiceButton("Flashcards", icon: "rectangle.stack.fill", kind: .flashcards)
                    practiceButton("Quiz", icon: "gamecontroller.fill", kind: .quiz)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                    ForEach(words) { word in
                        Button { selectedWord = word } label: { WordTile(word: word, box: boxes[word.id]) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(pack.title)
        .sheet(item: $selectedWord) { WordDetailView(word: $0).presentationDetents([.medium, .large]) }
        .practiceSession($practice)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", icon: "square.grid.2x2.fill", color: .accentColor, isSelected: category == nil) { category = nil }
                ForEach(categories, id: \.self) { id in
                    let info = WordCategory.info(for: id)
                    chip(title: info.title, icon: info.icon, color: info.color, isSelected: category == id) { category = id }
                }
            }
        }
    }

    private func chip(title: String, icon: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : color)
                .background(isSelected ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.12)), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func practiceButton(_ title: String, icon: String, kind: SessionKind) -> some View {
        Button {
            startPractice(kind)
        } label: {
            Label(title, systemImage: icon)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(kind == .quiz ? .accentColor : .blue)
        .disabled(words.isEmpty)
    }

    private func startPractice(_ kind: SessionKind) {
        let store = ProgressStore(context: modelContext)
        var rng = SystemRandomNumberGenerator()
        let picked = QuizBuilder.pickWords(from: words, states: store.reviewStates(), count: HomeView.sessionSize, using: &rng)
        let title = category.map { WordCategory.info(for: $0).title } ?? group.title
        // Wrong answers come from the whole pack so small categories still get 4 options.
        practice = PracticeRequest(kind: kind, title: title, words: picked, pool: repository.words(inPack: pack.id))
    }
}

private struct WordTile: View {
    let word: Word
    let box: Int?

    var body: some View {
        VStack(spacing: 6) {
            WordVisualView(visual: word.visual, size: 56, tint: word.tint)
            Text(word.displayDanish)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(word.english)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .topTrailing) {
            if let box, SpacedRepetition.isLearned(box: box) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .padding(6)
            }
        }
    }
}

struct WordDetailView: View {
    let word: Word

    var body: some View {
        VStack(spacing: 16) {
            WordVisualView(visual: word.visual, size: 140, tint: word.tint)
                .padding(.top, 24)
            HStack(spacing: 12) {
                Text(word.displayDanish).font(.largeTitle.bold())
                SpeakButton(word: word)
            }
            Text(word.english).font(.title3).foregroundStyle(.secondary)
            if let hint = word.grammarHint {
                Text(hint)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: Capsule())
            }
            VStack(spacing: 4) {
                HStack {
                    Text(word.exampleDa).font(.body.italic())
                    SpeakButton(text: word.exampleDa, size: .body)
                }
                Text(word.exampleEn).font(.callout).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding()
            Spacer()
        }
        .padding()
        .onAppear { SpeechService.shared.speak(word) }
    }
}
