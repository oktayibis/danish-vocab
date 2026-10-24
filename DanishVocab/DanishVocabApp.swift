import SwiftData
import SwiftUI

@main
struct DanishVocabApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [WordProgress.self, PlayerStats.self, EarnedBadge.self])
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Learn", systemImage: "book.fill") }
            PhrasesView()
                .tabItem { Label("Phrases", systemImage: "text.bubble.fill") }
            DictionaryView()
                .tabItem { Label("Dictionary", systemImage: "character.book.closed.fill") }
            BadgesView()
                .tabItem { Label("Badges", systemImage: "rosette") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}

/// A practice session to present full screen.
struct PracticeRequest: Identifiable {
    let id = UUID()
    let kind: SessionKind
    let title: String
    let words: [Word]
    /// Words that can be used as wrong answers.
    let pool: [Word]
}

extension View {
    func practiceSession(_ request: Binding<PracticeRequest?>) -> some View {
        fullScreenCover(item: request) { request in
            switch request.kind {
            case .quiz: QuizView(request: request)
            case .flashcards: FlashcardView(request: request)
            }
        }
    }
}
