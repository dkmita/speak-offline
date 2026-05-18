import AVFoundation

/// Reads Spanish text aloud via the built-in iOS speech synthesizer.
/// No bundled audio assets — Apple's offline neural voices handle any phrase
/// at runtime. Shared singleton so a tap on one card cancels playback from
/// another mid-utterance instead of queueing.
@MainActor
final class SpanishTTSService: NSObject, ObservableObject {
    static let shared = SpanishTTSService()

    private let synth = AVSpeechSynthesizer()

    @Published private(set) var isSpeaking = false

    override init() {
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String, languageCode: String = "es-ES") {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        // SpeechService may have left the audio session configured for
        // recording. Reclaim it for playback so the synthesizer's buffers
        // aren't dropped (the AVAudioBuffer.mm "mDataByteSize (0)" warning).
        // `.duckOthers` so background audio (music, podcasts) dips while
        // we speak, then returns.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? session.setActive(true, options: [])

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synth.speak(utterance)
    }

    func stop() {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
    }
}

extension SpanishTTSService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer,
                                       didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = true }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }
}
