import Foundation
import JamTapCore

/// Reads how loud the audio is that `catap` has written since the last reading.
/// While it records, `catap` writes into a hidden file next to the final one: `.<name>.wav.<random>.tmp`.
final class CaptureLevelMonitor {
    private let wav: URL
    private var file: FileHandle?
    private var format: WavFormat?
    private var nextOffset: UInt64 = 0
    private var formatIsUnsupported = false

    init(wav: URL) {
        self.wav = wav
    }

    /// Peak level in dBFS of the audio written since the last call; −∞ when nothing was written.
    /// Nil when the level cannot be read (samples that are not 16-bit integers).
    func peakDecibelsOfNewAudio() -> Double? {
        if formatIsUnsupported { return nil }
        guard let file = openedFile() else { return -.infinity }
        if format == nil {
            try? file.seek(toOffset: 0)
            guard let header = try? file.read(upToCount: 4096), let parsed = WavLevel.parseHeader(header) else {
                return -.infinity  // header not written yet
            }
            guard parsed.bitsPerSample == 16 else {
                formatIsUnsupported = true
                return nil
            }
            format = parsed
            nextOffset = UInt64(parsed.dataOffset)
        }
        try? file.seek(toOffset: nextOffset)
        guard let newBytes = try? file.readToEnd(), newBytes.count >= 2 else { return -.infinity }
        let wholeSamples = newBytes.prefix(newBytes.count - newBytes.count % 2)
        nextOffset += UInt64(wholeSamples.count)
        return WavLevel.decibels(ofPeak: WavLevel.peak(ofInt16Samples: wholeSamples))
    }

    private func openedFile() -> FileHandle? {
        if let file { return file }
        let directory = wav.deletingLastPathComponent()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        guard let temporaryName = names.first(where: {
            $0.hasPrefix("." + wav.lastPathComponent + ".") && $0.hasSuffix(".tmp")
        }) else { return nil }
        file = try? FileHandle(forReadingFrom: directory.appendingPathComponent(temporaryName))
        return file
    }
}
