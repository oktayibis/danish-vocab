import SwiftUI

struct WordPack: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let level: Int
    let files: [String]
    var comingSoon: Bool? = nil

    var isAvailable: Bool { comingSoon != true && !files.isEmpty }
}

/// Display info for the category ids used in the word files.
struct WordCategory: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let color: Color

    static func info(for id: String) -> WordCategory {
        known[id] ?? WordCategory(id: id, title: id.capitalized, icon: "square.grid.2x2.fill", color: .gray)
    }

    private static let known: [String: WordCategory] = Dictionary(uniqueKeysWithValues: [
        WordCategory(id: "food", title: "Food & drink", icon: "fork.knife", color: .orange),
        WordCategory(id: "home", title: "Home", icon: "house.fill", color: .brown),
        WordCategory(id: "family", title: "People", icon: "person.2.fill", color: .pink),
        WordCategory(id: "body", title: "Body", icon: "figure.stand", color: .red),
        WordCategory(id: "animals", title: "Animals", icon: "pawprint.fill", color: .green),
        WordCategory(id: "clothes", title: "Clothes", icon: "tshirt.fill", color: .purple),
        WordCategory(id: "nature", title: "Nature", icon: "leaf.fill", color: .mint),
        WordCategory(id: "time", title: "Time", icon: "clock.fill", color: .indigo),
        WordCategory(id: "places", title: "Places", icon: "building.2.fill", color: .teal),
        WordCategory(id: "transport", title: "Transport", icon: "bus.fill", color: .blue),
        WordCategory(id: "things", title: "Things & free time", icon: "gift.fill", color: .cyan),
        WordCategory(id: "work", title: "Work & school", icon: "briefcase.fill", color: .brown),
        WordCategory(id: "jobs", title: "Jobs", icon: "person.badge.key.fill", color: .indigo),
        WordCategory(id: "sport", title: "Sport & hobbies", icon: "figure.run", color: .green),
        WordCategory(id: "money", title: "Money & shopping", icon: "creditcard.fill", color: .yellow),
        WordCategory(id: "society", title: "Life & society", icon: "building.columns.fill", color: .indigo),
        WordCategory(id: "senses", title: "Taste, sound & weather", icon: "nose.fill", color: .mint),
        WordCategory(id: "numbers", title: "Numbers", icon: "number.circle.fill", color: .blue),
        WordCategory(id: "pronouns", title: "Pronouns", icon: "person.fill", color: .pink),
        WordCategory(id: "questions", title: "Question words", icon: "questionmark.bubble.fill", color: .orange),
        WordCategory(id: "prepositions", title: "Prepositions", icon: "arrow.up.and.down.and.arrow.left.and.right", color: .teal),
        WordCategory(id: "adverbs", title: "When, where & how", icon: "clock.arrow.circlepath", color: .purple),
        WordCategory(id: "conjunctions", title: "Linking words", icon: "link", color: .gray),
        WordCategory(id: "phrases", title: "Everyday phrases", icon: "text.bubble.fill", color: .green),
        WordCategory(id: "colors", title: "Colours", icon: "paintpalette.fill", color: .pink),
        WordCategory(id: "size", title: "Size & shape", icon: "ruler.fill", color: .brown),
        WordCategory(id: "feelings", title: "Feelings & people", icon: "face.smiling.inverse", color: .orange),
        WordCategory(id: "qualities", title: "Describing things", icon: "sparkles", color: .teal),
        WordCategory(id: "daily", title: "Daily life", icon: "sun.max.fill", color: .orange),
        WordCategory(id: "movement", title: "Movement", icon: "figure.walk", color: .green),
        WordCategory(id: "communication", title: "Talking", icon: "bubble.left.and.bubble.right.fill", color: .blue),
        WordCategory(id: "mind", title: "Senses & mind", icon: "brain.head.profile", color: .purple),
    ].map { ($0.id, $0) })
}
