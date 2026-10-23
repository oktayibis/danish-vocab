import Testing
import UIKit
@testable import DanishVocab

struct WordDataTests {
    let repository = WordRepository(bundle: Bundle(for: WordRepository.self))

    @Test func beginnerPackHas100NounsAnd100Verbs() {
        #expect(repository.words(inPack: "beginner", partOfSpeech: .noun).count == 100)
        #expect(repository.words(inPack: "beginner", partOfSpeech: .verb).count == 100)
    }

    @Test func elementaryPackHas250Words() {
        #expect(repository.words(inPack: "elementary", partOfSpeech: .noun).count == 100)
        #expect(repository.words(inPack: "elementary", partOfSpeech: .verb).count == 75)
        #expect(repository.words(inPack: "elementary", partOfSpeech: .adjective).count == 75)
    }

    @Test func intermediatePackHas500Words() {
        #expect(repository.words(inPack: "intermediate").count == 500)
        #expect(repository.words(inPack: "intermediate", group: .nouns).count == 160)
        #expect(repository.words(inPack: "intermediate", group: .verbs).count == 120)
        #expect(repository.words(inPack: "intermediate", group: .adjectives).count == 100)
        #expect(repository.words(inPack: "intermediate", group: .smallWords).count == 120)
    }

    @Test func advancedPackHas1000Words() {
        #expect(repository.words(inPack: "advanced").count == 1000)
        #expect(repository.words(inPack: "advanced", group: .nouns).count == 409)
        #expect(repository.words(inPack: "advanced", group: .verbs).count == 250)
        #expect(repository.words(inPack: "advanced", group: .adjectives).count == 200)
        #expect(repository.words(inPack: "advanced", group: .smallWords).count == 141)
        #expect(repository.allWords.count == 1950)
    }

    @Test func idsAreUnique() {
        let ids = repository.allWords.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func danishWordsAreUniquePerPartOfSpeech() {
        for part in PartOfSpeech.allCases {
            let words = repository.allWords.filter { $0.partOfSpeech == part }.map(\.displayDanish)
            let duplicates = Dictionary(grouping: words, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
            #expect(duplicates.isEmpty, "Duplicate \(part)s: \(duplicates)")
        }
    }

    @Test func wordsHaveTheirGrammarForms() {
        for word in repository.allWords {
            switch word.partOfSpeech {
            case .noun: #expect(["en", "et"].contains(word.article), "\(word.danish) needs en/et")
            case .verb:
                #expect(word.danish.hasPrefix("at "), "\(word.danish) should start with 'at'")
                #expect(word.present != nil && word.past != nil, "\(word.danish) needs present and past")
            case .adjective:
                #expect(word.neuter != nil && word.plural != nil, "\(word.danish) needs neuter and plural forms")
            case .adverb, .preposition, .pronoun, .conjunction, .number, .question, .phrase:
                #expect(word.article == nil && word.plural == nil, "\(word.danish) is a small word and takes no en/et or plural")
            }
        }
    }

    @Test func everyVisualRenders() {
        for word in repository.allWords {
            switch word.visual {
            case .emoji(let emoji): #expect(!emoji.isEmpty, "\(word.id) has an empty emoji")
            case .symbol(let name): #expect(UIImage(systemName: name) != nil, "\(word.id): unknown SF Symbol \(name)")
            case .drawing(let name): #expect(Drawings.names.contains(name), "\(word.id): unknown drawing \(name)")
            }
        }
    }

    @Test func badgeAndCategoryIconsExist() {
        for badge in Badges.all {
            #expect(UIImage(systemName: badge.icon) != nil, "Badge \(badge.id): unknown SF Symbol \(badge.icon)")
        }
        for id in Set(repository.allWords.map(\.category)) {
            #expect(UIImage(systemName: WordCategory.info(for: id).icon) != nil, "Category \(id) icon missing")
        }
    }

    @Test func everyQuizQuestionHasFourDistinctOptions() {
        var rng = SystemRandomNumberGenerator()
        for pack in repository.packs where pack.isAvailable {
            let pool = repository.words(inPack: pack.id)
            for word in pool {
            let options = QuizBuilder.options(for: word, pool: pool, using: &rng)
            #expect(options.count == 4)
            #expect(options.contains(word))
            #expect(Set(options.map(\.visual)).count == 4)
            #expect(options.allSatisfy { $0.partOfSpeech == word.partOfSpeech })
            }
        }
    }
}

struct DictionarySearchTests {
    let words = WordRepository(bundle: Bundle(for: WordRepository.self)).allWords

    func top(_ query: String) -> String? { DictionarySearch.search(query, in: words).first?.danish }

    @Test func findsDanishWithAndWithoutSpecialLetters() {
        #expect(top("æble") == "æble")
        #expect(top("aeble") == "æble")
        #expect(top("et æble") == "æble")
        #expect(top("kobe") == "at købe")
        #expect(top("koebe") == "at købe")
    }

    @Test func findsInflectedForms() {
        #expect(top("spiste") == "at spise")
        #expect(top("børn") == "barn")
        #expect(top("rødt") == "rød")
    }

    @Test func danishWinsOverEnglishFalseFriends() {
        // "fire" is Danish for four; English matches (ild, at fyre) come after it.
        let results = DictionarySearch.search("fire", in: words).map(\.danish)
        #expect(results.first == "fire")
        #expect(results.prefix(3).contains("ild"))
    }

    @Test func findsEnglishMeanings() {
        #expect(top("eat") == "at spise")
        #expect(top("dog") == "hund")
        #expect(top("yellow") == "gul")
        // "red" is also the Danish past tense of "at ride", which ranks first; the colour follows.
        #expect(DictionarySearch.search("red", in: words).prefix(2).map(\.danish) == ["at ride", "rød"])
    }

    @Test func exactMatchesComeFirst() {
        // "is" is a Danish word (ice cream) and must beat English words containing "is".
        #expect(top("is") == "is")
        let results = DictionarySearch.search("hus", in: words).map(\.danish)
        #expect(results.first == "hus")
    }

    @Test func emptyQueryListsEverythingAlphabetically() {
        let all = DictionarySearch.search("", in: words)
        #expect(all.count == words.count)
        // Danish order puts æ, ø, å after z.
        let letters = all.map { DictionarySearch.indexLetter(for: $0) }
        #expect(letters.first == "A")
        #expect(letters.last == "Å")
    }
}
