import SwiftData
import SwiftUI

struct QuizView: View {
    let request: PracticeRequest

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var questions: [QuizQuestion] = []
    @State private var index = 0
    @State private var selected: Word?
    @State private var correctCount = 0
    @State private var combo = 0
    @State private var answerXP = 0
    @State private var summary: RoundSummary?

    /// Correct answers in a row needed before each answer earns bonus XP.
    static let comboThreshold = 3
    static let comboBonus = 5

    private var question: QuizQuestion? { questions.indices.contains(index) ? questions[index] : nil }
    private var isAnswered: Bool { selected != nil }

    var body: some View {
        Group {
            if let summary {
                RoundResultView(summary: summary, title: request.title) { dismiss() }
            } else if let question {
                VStack(spacing: 20) {
                    SessionHeader(title: request.title, index: index, total: questions.count) { dismiss() }
                    scoreBar
                    prompt(for: question)
                        .frame(maxHeight: .infinity)
                    options(for: question)
                    if isAnswered { feedback(for: question) }
                }
                .padding()
                .animation(.spring(duration: 0.3), value: selected)
                .sensoryFeedback(trigger: selected) { _, newValue in
                    guard let newValue else { return nil }
                    return newValue == question.answer ? .success : .error
                }
            } else {
                ProgressView()
            }
        }
        .onAppear(perform: buildQuestions)
    }

    // MARK: - Pieces

    private var scoreBar: some View {
        HStack {
            Label("\(answerXP) XP", systemImage: "star.fill")
                .foregroundStyle(.yellow, .primary)
            Spacer()
            if combo >= Self.comboThreshold {
                Label("Combo ×\(combo)", systemImage: "bolt.fill")
                    .foregroundStyle(.orange)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .font(.subheadline.bold().monospacedDigit())
        .animation(.spring, value: combo)
    }

    @ViewBuilder
    private func prompt(for question: QuizQuestion) -> some View {
        VStack(spacing: 12) {
            switch question.mode {
            case .pictureToWord:
                Text("What is this in Danish?").font(.headline).foregroundStyle(.secondary)
                WordVisualView(visual: question.answer.visual, size: 170, tint: question.answer.tint)
                Text(question.answer.english).font(.title3).foregroundStyle(.secondary)
            case .wordToPicture:
                Text("Pick the right picture").font(.headline).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Text(question.answer.displayDanish).font(.system(size: 40, weight: .bold)).minimumScaleFactor(0.5)
                    SpeakButton(text: question.answer.displayDanish)
                }
            case .listenToPicture:
                Text("Listen and pick the picture").font(.headline).foregroundStyle(.secondary)
                Button {
                    SpeechService.shared.speak(question.answer.displayDanish)
                } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 56))
                        .padding(32)
                        .background(.tint.opacity(0.12), in: Circle())
                }
                .accessibilityLabel("Play word again")
                if isAnswered {
                    Text(question.answer.displayDanish).font(.title.bold())
                }
            }
        }
        .onAppear { if question.mode == .listenToPicture { SpeechService.shared.speak(question.answer.displayDanish) } }
        .id(question.id)
    }

    @ViewBuilder
    private func options(for question: QuizQuestion) -> some View {
        switch question.mode {
        case .pictureToWord:
            VStack(spacing: 10) {
                ForEach(question.options) { option in
                    optionButton(option, question: question) {
                        Text(option.displayDanish).font(.title3.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                }
            }
        case .wordToPicture, .listenToPicture:
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(question.options) { option in
                    optionButton(option, question: question) {
                        VStack(spacing: 4) {
                            WordVisualView(visual: option.visual, size: 72, tint: option.tint)
                            if isAnswered {
                                Text(option.english).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }

    private func optionButton<Label: View>(_ option: Word, question: QuizQuestion, @ViewBuilder label: () -> Label) -> some View {
        let state = optionState(option, question: question)
        return Button {
            choose(option, question: question)
        } label: {
            label()
                .background(state.fill, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(state.border, lineWidth: 2))
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(isAnswered)
        .accessibilityLabel(question.mode == .pictureToWord ? option.displayDanish : option.english)
    }

    private func optionState(_ option: Word, question: QuizQuestion) -> (fill: Color, border: Color) {
        guard let selected else { return (Color(.secondarySystemBackground), .clear) }
        if option == question.answer { return (.green.opacity(0.2), .green) }
        if option == selected { return (.red.opacity(0.2), .red) }
        return (Color(.secondarySystemBackground).opacity(0.5), .clear)
    }

    private func feedback(for question: QuizQuestion) -> some View {
        let correct = selected == question.answer
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(correct ? .green : .red)
                VStack(alignment: .leading) {
                    Text(correct ? ["Godt!", "Super!", "Flot!", "Perfekt!"].randomElement()! : "Not quite")
                        .font(.headline)
                    Text("\(question.answer.displayDanish) = \(question.answer.english)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Button(action: next) {
                Text(index + 1 < questions.count ? "Continue" : "See results")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(correct ? .green : .red)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Logic

    private func buildQuestions() {
        guard questions.isEmpty else { return }
        var rng = SystemRandomNumberGenerator()
        questions = QuizBuilder.makeQuestions(for: request.words, pool: request.pool, using: &rng)
    }

    private func choose(_ option: Word, question: QuizQuestion) {
        guard !isAnswered else { return }
        selected = option
        let correct = option == question.answer
        ProgressStore(context: modelContext).recordAnswer(wordId: question.answer.id, correct: correct)

        if correct {
            correctCount += 1
            combo += 1
            answerXP += XPReward.correctAnswer + (combo >= Self.comboThreshold ? Self.comboBonus : 0)
        } else {
            combo = 0
        }
        if question.mode != .listenToPicture {
            SpeechService.shared.speak(question.answer.displayDanish)
        }
    }

    private func next() {
        if index + 1 < questions.count {
            selected = nil
            index += 1
        } else {
            let result = SessionResult(kind: .quiz, correct: correctCount, total: questions.count, answerXP: answerXP)
            summary = ProgressStore(context: modelContext).finishSession(result)
        }
    }
}
