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
            case .adverb, .preposition, .pronoun, .conjunction, .number, .question, .phrase, .interjection, .proverb:
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

    @Test func everyWordHasItsOwnExampleSentence() {
        for word in repository.allWords {
            #expect(!word.exampleDa.isEmpty && !word.exampleEn.isEmpty, "\(word.id) needs an example in Danish and English")
        }
        let sentences = repository.allWords.map { $0.exampleDa.lowercased() }
        let duplicates = Dictionary(grouping: sentences, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
        #expect(duplicates.isEmpty, "Example sentences used by more than one word: \(duplicates)")
    }

    @Test func recordedAudioBelongsToWords() {
        let bundle = Bundle(for: WordRepository.self)
        let ids = Set(repository.allWords.map(\.id))
        // Word clips are <id>.mp3, example sentence clips <id>-ex.mp3.
        let clips = (bundle.urls(forResourcesWithExtension: "mp3", subdirectory: nil) ?? [])
            .map { $0.deletingPathExtension().lastPathComponent }
            .map { $0.hasSuffix("-ex") ? String($0.dropLast(3)) : $0 }
        let orphans = clips.filter { !ids.contains($0) }
        #expect(orphans.isEmpty, "Audio clips without a matching word: \(orphans)")
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
    let lookup = DictionaryLookup(bundle: Bundle(for: WordRepository.self))

    func top(_ query: String) -> String? { lookup.search(query).first?.danish }
    func results(_ query: String) -> [String] { lookup.search(query).map(\.danish) }

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
        // "fire" is Danish for four (and a verb, to lower); English matches like "ild" come after.
        #expect(results("fire").first == "fire")
        #expect(results("fire").prefix(5).contains("ild"))
    }

    @Test func findsEnglishMeanings() {
        #expect(top("eat") == "at spise")
        // "dog" is also a Danish word (however), which comes first; "hund" follows.
        #expect(results("dog").prefix(3).contains("hund"))
        #expect(top("yellow") == "gul")
        // "red" is also the Danish past tense of "at ride", which ranks first; the colour follows soon after.
        #expect(top("red") == "at ride")
        #expect(results("red").prefix(5).contains("rød"))
    }

    @Test func exactMatchesComeFirst() {
        // "is" is a Danish word (ice cream) and must beat English words containing "is".
        #expect(top("is") == "is")
        #expect(top("hus") == "hus")
    }

    @Test func packWordsAreNotListedTwice() {
        let ids = lookup.items.map(\.id)
        #expect(Set(ids).count == ids.count)
        // "hus" is a pack word, so the dictionary entry for it is hidden behind it.
        let hus = lookup.items.filter { $0.lemma == "hus" && $0.partOfSpeech == .noun }
        #expect(hus.count == 1)
        if case .word = hus.first {} else { Issue.record("hus should be the pack word") }
    }

    @Test func dictionaryAddsThousandsOfWords() {
        #expect(lookup.items.count > 20_000)
        for item in lookup.items {
            if case .entry(let entry) = item { #expect(!entry.m.isEmpty, "\(entry.w) has no meaning") }
        }
        #expect(top("sommerhus") == "sommerhus")
        #expect(top("flødebolle") == "flødebolle")
    }

    @Test func packWordsGetSynonymsAndAntonyms() {
        let glad = WordRepository(bundle: Bundle(for: WordRepository.self)).allWords.first { $0.danish == "glad" }!
        let related = lookup.related(to: glad)
        #expect(related.synonyms.contains("fornøjet"))
        #expect(related.antonyms.contains("trist"))
        // Wiktionary lists the pair under "glad" only; it should show from the other side too.
        guard case .entry(let fornøjet)? = lookup.item(for: "fornøjet", preferring: .adjective) else {
            Issue.record("fornøjet should be a dictionary entry"); return
        }
        #expect(lookup.related(to: .entry(fornøjet)).synonyms.contains("glad"))
    }

    @Test func browsingIsAlphabeticalWithÆØÅLast() {
        let letters = lookup.sections(group: nil).map(\.letter).filter { $0 != "#" }
        #expect(letters.first == "A")
        #expect(letters.suffix(3) == ["Æ", "Ø", "Å"])
    }
}
