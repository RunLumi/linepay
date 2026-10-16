import AVFoundation
import Foundation
import Observation
import Speech

/// Platform adapter only. Audio is temporary, excluded from backups and never offered to a server.
@MainActor
@Observable
final class LocalVoiceCapture: NSObject, AVAudioRecorderDelegate {
    enum Phase: Equatable { case idle, permission, recording, transcribing, finished, failed }
    private(set) var phase: Phase = .idle
    private(set) var text = ""
    private(set) var message: String?
    private(set) var cleanupIssue = false
    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var recognizer: SFSpeechRecognizer?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var timeout: Task<Void, Never>?
    @ObservationIgnored private var audioURL: URL?
    @ObservationIgnored private var generation = UUID()

    var busy: Bool { phase == .permission || phase == .recording || phase == .transcribing }

    func start() async {
        guard !busy else { return }
        cancel()
        let token = generation
        guard !cleanupIssue else {
            message =
                "Temporary audio cleanup is pending. Reopen the app or use Delete all local data after backing up pay records. No new recording was started."
            phase = .failed
            return
        }
        message = nil
        phase = .permission
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US")),
            recognizer.supportsOnDeviceRecognition, recognizer.isAvailable
        else {
            fail(
                "On-device English recognition is unavailable. Type the reading or use the work editor; audio will not be sent to a server.",
                token: token)
            return
        }
        let authorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard generation == token else { return }
        guard authorized else {
            fail(
                "Speech permission is unavailable. You can change it in iOS Settings or enter work manually.",
                token: token)
            return
        }
        let microphone = await AVAudioApplication.requestRecordPermission()
        guard generation == token else { return }
        guard microphone else {
            fail(
                "Microphone permission is unavailable. You can change it in iOS Settings or enter work manually.",
                token: token)
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)
            let url = try LocalVoiceAudioFiles.newURL()
            audioURL = url
            self.recognizer = recognizer
            let recorder = try AVAudioRecorder(
                url: url,
                settings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 16_000,
                    AVNumberOfChannelsKey: 1,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                ])
            self.recorder = recorder
            recorder.delegate = self
            guard recorder.prepareToRecord() else { throw CocoaError(.fileWriteUnknown) }
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
            guard recorder.record(forDuration: 60) else { throw CocoaError(.fileWriteUnknown) }
            phase = .recording
        } catch {
            fail(
                "Recording could not start. No work was saved. Check microphone availability or enter work manually.",
                token: token)
        }
    }

    func stopAndTranscribe() {
        guard phase == .recording else { return }
        recorder?.delegate = nil
        recorder?.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        transcribe(token: generation)
    }

    func cancel() {
        generation = UUID()
        timeout?.cancel()
        timeout = nil
        task?.cancel()
        task = nil
        recorder?.delegate = nil
        recorder?.stop()
        recorder = nil
        recognizer = nil
        if let audioURL {
            do {
                try LocalVoiceAudioFiles.remove(audioURL)
                self.audioURL = nil
                cleanupIssue = false
            } catch { cleanupIssue = true }
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        phase = .idle
    }

    nonisolated func audioRecorderDidFinishRecording(
        _ recorder: AVAudioRecorder, successfully flag: Bool
    ) {
        let recorderID = ObjectIdentifier(recorder)
        Task { @MainActor [weak self] in
            guard let self, self.phase == .recording,
                self.recorder.map(ObjectIdentifier.init) == recorderID
            else { return }
            if flag {
                self.stopAndTranscribe()
            } else {
                self.fail(
                    "Recording was interrupted. Review or enter work manually; nothing was saved.",
                    token: self.generation)
            }
        }
    }

    private func transcribe(token: UUID) {
        guard let url = audioURL, let recognizer,
            recognizer.supportsOnDeviceRecognition, recognizer.isAvailable
        else {
            fail(
                "On-device recognition became unavailable. No server fallback was used; enter work manually.",
                token: token)
            return
        }
        phase = .transcribing
        let request = Self.request(url: url)
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Cross the actor boundary with values, never the SDK result/error objects.
            let reading = result?.isFinal == true ? result?.bestTranscription.formattedString : nil
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self, self.generation == token, self.phase == .transcribing else {
                    return
                }
                if let reading, !reading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    guard reading.count <= 2_000 else {
                        self.fail(
                            "The reading is too long to review here. Enter the work manually; nothing was saved.",
                            token: token)
                        return
                    }
                    self.text = reading
                    self.cancel()
                    self.phase = .finished
                } else if failed {
                    self.fail(
                        "On-device recognition could not read this recording. Try again or type the reading. No work was saved.",
                        token: token)
                }
            }
        }
        timeout = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            self?.fail(
                "Recognition timed out. No server fallback was used and no work was saved. Try again or enter work manually.",
                token: token)
        }
    }

    /// Kept visible to app tests so the real framework request's privacy flags are checked.
    static func request(url: URL) -> SFSpeechURLRecognitionRequest {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        return request
    }

    private func fail(_ message: String, token: UUID) {
        guard generation == token else { return }
        cancel()
        self.message = message
        phase = .failed
    }
}

enum LocalVoiceAudioFiles {
    static var directory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "LinePayVoice", isDirectory: true)
    }
    static func newURL() throws -> URL {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        guard try directory.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true
        else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        var folder = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
        return directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
    }
    static func remove(_ url: URL) throws {
        guard url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL,
            url.pathExtension == "caf",
            UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil
        else { throw CocoaError(.fileWriteInvalidFileName) }
        guard try directory.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true
        else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    static func removeAll() throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        guard try directory.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true
        else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil)
        for url in urls
        where url.pathExtension == "caf"
            && UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil
        {
            try remove(url)
        }
    }
    /// Called at process startup: recordings left by termination are not financial evidence.
    static func removeAbandoned() { try? removeAll() }
}
