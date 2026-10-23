import AVFoundation

/// Speaks Danish: a recorded clip for words when one is bundled (Audio/<word id>.mp3, made with
/// scripts/generate_audio.swift), otherwise the best da-DK voice installed on the device.
final class SpeechService: NSObject {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?

    /// Premium or enhanced voices sound much better than the default compact one, if the user has downloaded them
    /// (Settings › Accessibility › Spoken Content › Voices › Danish).
    private lazy var voice: AVSpeechSynthesisVoice? = {
        let danish = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "da-DK" }
        return danish.max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: "da-DK")
    }()

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ word: Word) {
        guard let url = Bundle.main.url(forResource: word.id, withExtension: "mp3"),
              let player = try? AVAudioPlayer(contentsOf: url)
        else {
            speak(word.displayDanish)
            return
        }
        stop()
        activateAudioSession()
        player.delegate = self
        self.player = player
        player.play()
    }

    func speak(_ text: String) {
        stop()
        activateAudioSession()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        synthesizer.speak(utterance)
    }

    private func stop() {
        player?.stop()
        player = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    /// The default session category is silenced by the Ring/Silent switch, so on a real iPhone
    /// nothing is heard in silent mode. Pronunciation is the point of the app, so play it anyway
    /// and briefly lower any music that is playing.
    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("SpeechService: could not activate audio session: \(error)")
        }
    }

    /// Hand the audio back to other apps (e.g. un-duck their music) once we are done talking.
    private func deactivateAudioSessionIfIdle() {
        guard !synthesizer.isSpeaking, player?.isPlaying != true else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.deactivateAudioSessionIfIdle() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.deactivateAudioSessionIfIdle() }
    }
}

extension SpeechService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.deactivateAudioSessionIfIdle() }
    }
}
