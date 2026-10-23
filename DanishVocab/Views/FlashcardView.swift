import SwiftData
import SwiftUI

struct FlashcardView: View {
    let request: PracticeRequest

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var isFlipped = false
    @State private var knownCount = 0
    @State private var summary: RoundSummary?

    private var word: Word { request.words[index] }

    var body: some View {
        if let summary {
            RoundResultView(summary: summary, title: request.title) { dismiss() }
        } else {
            VStack(spacing: 24) {
                SessionHeader(title: request.title, index: index, total: request.words.count) { dismiss() }

                card
                    .onTapGesture { flip() }

                if isFlipped {
                    HStack(spacing: 16) {
                        answerButton("Again", icon: "arrow.counterclockwise", color: .orange, knewIt: false)
                        answerButton("Knew it", icon: "checkmark", color: .green, knewIt: true)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Text("Tap the card to see the word")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(height: 56)
                }
            }
            .padding()
            .animation(.spring(duration: 0.35), value: isFlipped)
        }
    }

    private var card: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(.background)
                .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
            if isFlipped {
                back.rotation3DEffect(.degrees(180), axis: (0, 1, 0))
            } else {
                front
            }
        }
        .frame(maxHeight: .infinity)
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (0, 1, 0))
    }

    private var front: some View {
        VStack(spacing: 16) {
            WordVisualView(visual: word.visual, size: 180, tint: word.tint)
            Text(word.english).font(.title2).foregroundStyle(.secondary)
        }
    }

    private var back: some View {
        VStack(spacing: 14) {
            WordVisualView(visual: word.visual, size: 90, tint: word.tint)
            HStack(spacing: 12) {
                Text(word.displayDanish).font(.largeTitle.bold()).minimumScaleFactor(0.6)
                SpeakButton(word: word)
            }
            Text(word.english).font(.title3).foregroundStyle(.secondary)
            if let hint = word.grammarHint {
                Text(hint).font(.callout).padding(.horizontal, 12).padding(.vertical, 6).background(.quaternary, in: Capsule())
            }
            VStack(spacing: 4) {
                HStack {
                    Text(word.exampleDa).font(.body.italic())
                    SpeakButton(exampleOf: word, size: .body)
                }
                Text(word.exampleEn).font(.callout).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal)
        }
        .padding()
    }

    private func answerButton(_ title: String, icon: String, color: Color, knewIt: Bool) -> some View {
        Button {
            answer(knewIt: knewIt)
        } label: {
            Label(title, systemImage: icon).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .sensoryFeedback(knewIt ? .success : .warning, trigger: index)
    }

    private func flip() {
        guard !isFlipped else { return }
        isFlipped = true
        SpeechService.shared.speak(word)
    }

    private func answer(knewIt: Bool) {
        let store = ProgressStore(context: modelContext)
        store.recordAnswer(wordId: word.id, correct: knewIt)
        if knewIt { knownCount += 1 }

        if index + 1 < request.words.count {
            isFlipped = false
            index += 1
        } else {
            let result = SessionResult(
                kind: .flashcards,
                correct: knownCount,
                total: request.words.count,
                answerXP: request.words.count * XPReward.flashcardReview)
            summary = store.finishSession(result)
        }
    }
}

/// Close button, title and progress bar shared by the practice screens.
struct SessionHeader: View {
    let title: String
    let index: Int
    let total: Int
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close")
                Spacer()
                Text(title).font(.headline)
                Spacer()
                Text("\(index + 1)/\(total)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(index), total: Double(max(total, 1)))
                .tint(.green)
        }
    }
}
