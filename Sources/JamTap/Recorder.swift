import Foundation
import JamTapCore

/// How one take ended.
enum TakeResult {
    /// The take is saved; `url` is the MP3, or the directory of a take with one track per app.
    case saved(URL)
    /// The take is saved but holds only digital silence, which is what macOS delivers when the app
    /// lacks the permission to record system audio.
    case savedSilent(URL)
    /// The recording exists but something went wrong afterwards; `url` is what was kept.
    case keptUnconverted(URL, reason: String)
    case failed(reason: String)
}

/// Records takes with `catap` and converts them to MP3 with `ffmpeg`.
/// A new take can start while earlier ones are still being converted.
final class Recorder {
    private struct Capture {
        let take: Take
        let output: CaptureOutput
        let process: Process
        let startedAt: Date
        let levelMonitor: CaptureLevelMonitor?
        var silenceDetector = SilenceDetector()
    }

    private enum State {
        case idle
        case recording(Capture)
        /// `catap` was told to stop and is closing its file.
        case stopping(Capture)
    }

    private var state = State.idle
    private var everySecond: Timer?
    private(set) var conversionsInProgress = 0

    /// Called on the main thread whenever something the menu bar shows has changed.
    var onChange: () -> Void = {}
    var onTakeFinished: (TakeResult) -> Void = { _ in }

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    /// True while a take is being recorded, closed or converted.
    var isBusy: Bool {
        if case .idle = state { return conversionsInProgress > 0 }
        return true
    }

    var elapsedSeconds: Double? {
        if case .recording(let capture) = state { return Date().timeIntervalSince(capture.startedAt) }
        return nil
    }

    var isSilentTooLong: Bool {
        if case .recording(let capture) = state { return capture.silenceDetector.isSilentTooLong }
        return false
    }

    func toggle() {
        switch state {
        case .idle: start()
        case .recording: stop()
        case .stopping: break
        }
    }

    func start() {
        guard case .idle = state else { return }
        guard let catap = Tools.catap else {
            onTakeFinished(.failed(reason: "catap is not installed. JamTap looks in ~/.local/bin, /opt/homebrew/bin and /usr/local/bin."))
            return
        }
        let directory = Settings.recordingsDirectory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            onTakeFinished(.failed(reason: "Cannot create \(directory.path): \(error.localizedDescription)"))
            return
        }
        let existingNames = ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
            .map { ($0 as NSString).deletingPathExtension }
        let take = Take(directory: directory,
                        name: TakeName.firstUnused(TakeName.timestamped(at: Date()), among: Set(existingNames)))
        let chosenApps = Settings.chosenApps
        let processes = Settings.sourceKind == .systemMix ? [] : Tools.audioProcesses()
        guard let source = RecordingSource.resolved(kind: Settings.sourceKind, chosenApps: chosenApps, processes: processes) else {
            onTakeFinished(.failed(reason: chosenApps.isEmpty
                ? "No app is checked. Check apps in the Record menu, or choose Everything the Mac Plays."
                : "None of the checked apps has audio open: \(chosenApps.joined(separator: ", "))."))
            return
        }
        let output = CaptureCommand.output(source: source, take: take)

        guard let process = Tools.run(catap, CaptureCommand.catapArguments(source: source, take: take), logName: "catap",
                                      completion: { [weak self] _ in self?.captureEnded() })
        else {
            onTakeFinished(.failed(reason: "Could not start \(catap.path)."))
            return
        }
        // The level is read from the single WAV only; a take with one track per app is not monitored.
        var levelMonitor: CaptureLevelMonitor?
        if case .singleWav(let wav) = output { levelMonitor = CaptureLevelMonitor(wav: wav) }
        state = .recording(Capture(take: take, output: output, process: process, startedAt: Date(), levelMonitor: levelMonitor))

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.secondPassed() }
        RunLoop.main.add(timer, forMode: .common)  // .common keeps it running while a menu is open
        everySecond = timer
        onChange()
    }

    func stop() {
        guard case .recording(let capture) = state else { return }
        state = .stopping(capture)
        everySecond?.invalidate()
        // SIGINT, like Ctrl+C in a terminal: catap then finishes the WAV file properly and exits.
        capture.process.interrupt()
        onChange()

        // catap cannot react to the signal while it is stuck setting up, for instance while macOS
        // waits for an answer to its audio-capture permission question. Nothing has been captured
        // then, so it is ended. A catap that did record is left to finish its file, however long that takes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, case .stopping(let stuck) = self.state, stuck.process === capture.process,
                  stuck.process.isRunning else { return }
            let printed = (try? String(contentsOf: Tools.logFile(named: "catap"), encoding: .utf8)) ?? ""
            if !CaptureCommand.catapHasStartedRecording(output: printed) {
                stuck.process.terminate()
            }
        }
    }

    private func secondPassed() {
        guard case .recording(var capture) = state, let elapsed = elapsedSeconds else { return }
        if let peakDecibels = capture.levelMonitor?.peakDecibelsOfNewAudio() {
            capture.silenceDetector.observe(peakDecibels: peakDecibels, atSecond: elapsed)
            state = .recording(capture)
        }
        let autoStopMinutes = Settings.autoStopMinutes
        if autoStopMinutes > 0, elapsed >= Double(autoStopMinutes) * 60 {
            stop()
        }
        onChange()
    }

    /// `catap` has exited, after `stop()` or by itself (an error, or the recorded app quit).
    private func captureEnded() {
        let capture: Capture
        switch state {
        case .recording(let ended), .stopping(let ended): capture = ended
        case .idle: return
        }
        everySecond?.invalidate()
        state = .idle
        let wavs: [URL], result: URL
        switch capture.output {
        case .singleWav(let wav):
            wavs = [wav].filter(fileHasContent)
            result = capture.take.mp3
        case .trackDirectory(let directory):
            wavs = ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.pathExtension.lowercased() == "wav" && fileHasContent($0) }
            result = directory
        }
        guard !wavs.isEmpty else {
            onTakeFinished(.failed(reason: "No recording was made.\n" + Tools.lastOutput(logName: "catap")))
            onChange()
            return
        }
        // Files of pure digital silence are dropped, unless that would leave nothing: an app with
        // several audio processes gives one track per process, and most of them stay silent.
        // Reading whole files takes a while for a long take, so it happens off the main thread.
        conversionsInProgress += 1
        onChange()
        DispatchQueue.global(qos: .userInitiated).async {
            let wavsWithSound = wavs.filter { WavLevel.peak(ofFile: $0) != 0 }
            if !wavsWithSound.isEmpty {
                for silentWav in wavs where !wavsWithSound.contains(silentWav) {
                    try? FileManager.default.removeItem(at: silentWav)
                }
            }
            DispatchQueue.main.async {
                self.convert(wavsWithSound.isEmpty ? wavs : wavsWithSound, savedAs: result, takeIsSilent: wavsWithSound.isEmpty)
                self.conversionsInProgress -= 1
                self.onChange()
            }
        }
    }

    /// Converts each WAV to an MP3 beside it and deletes the WAV; reports once when all are done.
    private func convert(_ wavs: [URL], savedAs result: URL, takeIsSilent: Bool) {
        guard let ffmpeg = Tools.ffmpeg else {
            onTakeFinished(.keptUnconverted(wavs.count == 1 ? wavs[0] : result,
                                            reason: "ffmpeg is not installed, so the take stays a WAV."))
            return
        }
        var remaining = wavs.count
        var failures: [URL] = []
        conversionsInProgress += 1
        for wav in wavs {
            let mp3 = wav.deletingPathExtension().appendingPathExtension("mp3")
            let finished: (Int32) -> Void = { [weak self] exitStatus in
                guard let self else { return }
                if exitStatus == 0, self.fileHasContent(mp3) {
                    try? FileManager.default.removeItem(at: wav)
                } else {
                    failures.append(wav)
                }
                remaining -= 1
                guard remaining == 0 else { return }
                self.conversionsInProgress -= 1
                if failures.isEmpty {
                    self.onTakeFinished(takeIsSilent ? .savedSilent(result) : .saved(result))
                } else {
                    self.onTakeFinished(.keptUnconverted(failures.count == 1 ? failures[0] : result,
                                                         reason: "MP3 conversion failed, so the WAV is kept.\n"
                                                             + Tools.lastOutput(logName: "ffmpeg")))
                }
                self.onChange()
            }
            if Tools.run(ffmpeg, CaptureCommand.ffmpegArguments(wav: wav, mp3: mp3), logName: "ffmpeg", completion: finished) == nil {
                finished(-1)
            }
        }
    }

    private func fileHasContent(_ url: URL) -> Bool {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        return size > 0
    }
}
