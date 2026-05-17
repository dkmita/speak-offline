import AVFoundation
import Speech

@MainActor
final class SpeechService: ObservableObject {
    @Published var isListening = false
    @Published var transcript = ""
    @Published var error: String?

    /// Called on each partial transcript update (for live display)
    var onPartialResult: ((String) -> Void)?
    /// Contextual phrases to hint the recognizer — set before calling startListening()
    var contextualStrings: [String] = []

    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    private let speechRecognizer: SFSpeechRecognizer?

    init(locale: Locale = Locale(identifier: "es-ES")) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    var isAvailable: Bool {
        speechRecognizer?.isAvailable ?? false
    }

    // MARK: - Permissions

    func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        print("[SpeakOffline] Speech auth status: \(speechStatus.rawValue)")
        guard speechStatus == .authorized else {
            error = "Speech recognition not authorized"
            return false
        }

        let audioStatus: Bool
        if #available(iOS 17.0, *) {
            audioStatus = await AVAudioApplication.requestRecordPermission()
        } else {
            audioStatus = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        print("[SpeakOffline] Mic auth: \(audioStatus)")
        guard audioStatus else {
            error = "Microphone access not authorized"
            return false
        }

        return true
    }

    // MARK: - Start / Stop

    func startListening() {
        guard let speechRecognizer else {
            error = "Speech recognizer not available for this language"
            print("[SpeakOffline] No speech recognizer")
            return
        }
        guard speechRecognizer.isAvailable else {
            error = "Speech recognizer not available — download the offline language pack in Settings"
            print("[SpeakOffline] Speech recognizer not available")
            return
        }

        // Reset state
        stopListening()
        transcript = ""
        error = nil

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("[SpeakOffline] Audio session active")

            let audioEngine = AVAudioEngine()
            let request = SFSpeechAudioBufferRecognitionRequest()

            // Force on-device recognition for offline use
            if speechRecognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            request.shouldReportPartialResults = true
            request.contextualStrings = contextualStrings
            request.taskHint = .dictation

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            self.audioEngine = audioEngine
            self.recognitionRequest = request
            self.isListening = true
            print("[SpeakOffline] Listening started, onDevice=\(speechRecognizer.supportsOnDeviceRecognition)")

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                        self.onPartialResult?(self.transcript)
                    }

                    if let error, self.isListening {
                        print("[SpeakOffline] Recognition error: \(error)")
                        self.error = error.localizedDescription
                        self.stopListening()
                    }
                }
            }
        } catch {
            print("[SpeakOffline] startListening failed: \(error)")
            self.error = error.localizedDescription
            stopListening()
        }
    }

    func stopListening() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
