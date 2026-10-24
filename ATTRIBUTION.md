# Attribution

Danish Vocab is built on open data and a few services. This file credits them and states their licences. The app shows the same information under **Profile › About, sources & licences** (`DanishVocab/Views/AboutView.swift`), and each dictionary entry links to its Wiktionary page.

## Dictionary: Wiktionary

- **What:** about 23,000 Danish words with English meanings, inflected forms, IPA pronunciation, synonyms and antonyms (`DanishVocab/Data/dictionary.json`).
- **Authors:** [Wiktionary contributors](https://en.wiktionary.org/wiki/Wiktionary:Copyrights), Danish entries of [English Wiktionary](https://en.wiktionary.org).
- **Extracted by:** [kaikki.org](https://kaikki.org/dictionary/Danish/) with [wiktextract](https://github.com/tatuylonen/wiktextract) by Tatu Ylonen. Tatu Ylonen: *Wiktextract: Wiktionary as Machine-Readable Structured Data*, Proceedings of the 13th Conference on Language Resources and Evaluation (LREC), pp. 1317–1325, Marseille, 2022.
- **Licence:** [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) (Wiktionary text is also available under the GFDL).
- **Changes:** `scripts/import_dictionary.swift` keeps up to six meanings and the main inflected forms per entry, merges entries with the same word and part of speech, drops form-of entries, adds a frequency rank, and adds the words in `scripts/extra_words.json`.
- **Share-alike:** `dictionary.json`, including the extra words, is shared under CC BY-SA 4.0.

## Word frequency: FrequencyWords and OpenSubtitles

- **What:** the Danish 50,000-word frequency list, used only to rank dictionary entries. The list itself is not included in the app.
- **Author:** [Hermit Dave, FrequencyWords](https://github.com/hermitdave/FrequencyWords) (content CC BY-SA 4.0, code MIT).
- **Underlying data:** the [OpenSubtitles 2018](https://opus.nlpl.eu/OpenSubtitles2018.php) corpus from [OPUS](https://opus.nlpl.eu) (P. Lison and J. Tiedemann, *OpenSubtitles2016: Extracting Large Parallel Corpora from Movie and TV Subtitles*, LREC 2016), built from subtitles on [opensubtitles.org](https://www.opensubtitles.org).
- **Licence:** [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

## Extra everyday words

- **What:** 47 words Wiktionary lacks, such as *Rejsekort*, *MitID* and *pantbon* (`scripts/extra_words.json`).
- **Author:** Danish Vocab, written with Claude (Anthropic).
- **Licence:** CC BY-SA 4.0, as part of `dictionary.json`.

## Learning words, pictures and sentences

- **What:** the 1950 pack words with their example sentences and pictures, the 360 practical sentences (`scripts/sentences/situations.json`) and one example sentence for every dictionary word (`scripts/sentences/words.json`).
- **Author:** Oktay Ibis, written with Claude (Anthropic): Claude Sonnet for the situations and the ~5,000 most frequent words, Claude Haiku for the rest.
- **Licence:** [MIT](LICENSE).
- They have not yet been fully reviewed by a native Danish speaker. Corrections are welcome as issues or pull requests.

## Pronunciation

- **Recordings:** `DanishVocab/Audio` was generated with [ElevenLabs](https://elevenlabs.io) (voice "Søren") on a paid plan, under the [ElevenLabs terms](https://elevenlabs.io/terms-of-use).
- **Device voice:** sentences without a recording are read by the Danish voice of iOS (Apple).

## App

- **Code, icon and drawings:** Oktay Ibis, written with Claude (Anthropic) in Claude Code. [MIT](LICENSE).
- Emoji and SF Symbols are drawn by iOS on the device; they are not bundled with the app.
