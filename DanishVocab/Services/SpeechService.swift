import AVFoundation

/// Speaks Danish with the best da-DK voice installed on the device.
final class SpeechService: NSObject {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()

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

    func speak(_ text: String) {
        activateAudioSession()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        synthesizer.speak(utterance)
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
    nonisolated private func deactivateAudioSessionIfIdle(_ synthesizer: AVSpeechSynthesizer) {
        guard !synthesizer.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        deactivateAudioSessionIfIdle(synthesizer)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        deactivateAudioSessionIfIdle(synthesizer)
    }
}
