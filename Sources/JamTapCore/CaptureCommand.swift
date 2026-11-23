import Foundation

/// What the user chose to record.
public enum SourceKind: String, CaseIterable, Sendable {
    /// Everything the Mac plays, mixed into one file.
    case systemMix
    /// Only the chosen apps, mixed into one file.
    case mixOfApps
    /// Only the chosen apps, one file per process, so that guitar and backing track stay separate.
    case separateTrackPerApp
}

/// What one take records: the user's choice, with the chosen apps resolved to their running processes.
public enum RecordingSource: Equatable, Sendable {
    case systemMix
    case mixOfProcesses([Int])
    case separateTrackPerProcess([Int])

    /// Nil when apps are to be recorded but none of the chosen ones has an audio process.
    public static func resolved(kind: SourceKind, chosenApps: [String], processes: [AudioProcess]) -> RecordingSource? {
        if kind == .systemMix { return .systemMix }
        let processIDs = AudioAppList.processIDs(ofApps: chosenApps, among: processes)
        if processIDs.isEmpty { return nil }
        return kind == .mixOfApps ? .mixOfProcesses(processIDs) : .separateTrackPerProcess(processIDs)
    }
}

/// The files of one take.
public struct Take: Equatable, Sendable {
    public let directory: URL
    public let name: String

    public init(directory: URL, name: String) {
        self.directory = directory
        self.name = name
    }

    public var wav: URL { directory.appendingPathComponent(name + ".wav") }
    public var mp3: URL { directory.appendingPathComponent(name + ".mp3") }
    /// Holds one file per app when tracks are recorded separately.
    public var trackDirectory: URL { directory.appendingPathComponent(name, isDirectory: true) }
}

/// Where `catap` leaves the recording.
public enum CaptureOutput: Equatable, Sendable {
    case singleWav(URL)
    case trackDirectory(URL)
}

/// Command lines of the two tools JamTap runs: `catap` records, `ffmpeg` converts WAV to MP3.
public enum CaptureCommand {
    public static func catapArguments(source: RecordingSource, take: Take) -> [String] {
        switch (source, output(source: source, take: take)) {
        case (.systemMix, _):
            return ["record", "--system", "-o", take.wav.path]
        case (.mixOfProcesses(let processIDs), _), (.separateTrackPerProcess(let processIDs), .singleWav):
            return ["record", "-o", take.wav.path] + processIDs.flatMap { ["--pid", String($0)] }
        case (.separateTrackPerProcess(let processIDs), .trackDirectory(let directory)):
            return ["record-multitrack", "-o", directory.path] + processIDs.flatMap { ["--pid", String($0)] }
        }
    }

    /// `catap record-multitrack` needs at least two tracks, so a single process is recorded as one file.
    public static func output(source: RecordingSource, take: Take) -> CaptureOutput {
        if case .separateTrackPerProcess(let processIDs) = source, processIDs.count >= 2 {
            return .trackDirectory(take.trackDirectory)
        }
        return .singleWav(take.wav)
    }

    /// Whether `catap`, judging by what it has printed, got as far as capturing audio. Before that it
    /// announces its sources ("Recording from: …", "Recording global …"); the capture itself starts
    /// with "Recording..." or "Recording for N seconds...".
    public static func catapHasStartedRecording(output: String) -> Bool {
        output.split(separator: "\n").contains { $0.hasPrefix("Recording...") || $0.hasPrefix("Recording for ") }
    }

    /// Variable-bitrate MP3 at LAME quality 2 (about 190 kbit/s). Without `-y`, ffmpeg refuses to overwrite.
    public static func ffmpegArguments(wav: URL, mp3: URL) -> [String] {
        ["-hide_banner", "-loglevel", "error", "-nostdin", "-i", wav.path,
         "-codec:a", "libmp3lame", "-q:a", "2", mp3.path]
    }
}
