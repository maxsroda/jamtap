import Foundation

/// What is recorded.
public enum RecordingSource: Equatable, Sendable {
    /// Everything the Mac plays, mixed into one file.
    case systemMix
    /// Only the named apps, mixed into one file.
    case mixOfApps([String])
    /// Only the named apps, one file per app, so that guitar and backing track stay separate.
    case separateTrackPerApp([String])
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
        // "--" ends the options, so an app name that starts with "-" is not read as one.
        switch source {
        case .mixOfApps(let apps) where !apps.isEmpty:
            return ["record", "-o", take.wav.path, "--"] + apps
        case .separateTrackPerApp(let apps) where !apps.isEmpty:
            return ["record-multitrack", "-o", take.trackDirectory.path, "--"] + apps
        case .systemMix, .mixOfApps, .separateTrackPerApp:
            // No app chosen: record everything rather than nothing.
            return ["record", "--system", "-o", take.wav.path]
        }
    }

    public static func output(source: RecordingSource, take: Take) -> CaptureOutput {
        if case .separateTrackPerApp(let apps) = source, !apps.isEmpty {
            return .trackDirectory(take.trackDirectory)
        }
        return .singleWav(take.wav)
    }

    /// Variable-bitrate MP3 at LAME quality 2 (about 190 kbit/s). Without `-y`, ffmpeg refuses to overwrite.
    public static func ffmpegArguments(wav: URL, mp3: URL) -> [String] {
        ["-hide_banner", "-loglevel", "error", "-nostdin", "-i", wav.path,
         "-codec:a", "libmp3lame", "-q:a", "2", mp3.path]
    }
}
