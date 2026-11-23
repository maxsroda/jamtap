import Foundation

public struct WavFormat: Equatable, Sendable {
    public let channelCount: Int
    public let bitsPerSample: Int
    public let sampleRate: Int
    /// Byte offset of the first sample in the file.
    public let dataOffset: Int

    public var bytesPerSecond: Int { sampleRate * channelCount * bitsPerSample / 8 }
}

/// Reads the loudness of a WAV file while `catap` is still writing it.
public enum WavLevel {
    /// The format and sample offset from the first bytes of a WAV file, or nil if the header is
    /// incomplete or the samples are not integer PCM. The chunk sizes of an unfinished file are stale,
    /// so only the chunks before the samples are trusted.
    public static func parseHeader(_ bytes: Data) -> WavFormat? {
        let bytes = Data(bytes)  // re-base indices to zero
        guard bytes.count >= 12, bytes[0..<4] == Data("RIFF".utf8), bytes[8..<12] == Data("WAVE".utf8) else { return nil }
        var format: (channelCount: Int, sampleRate: Int, bitsPerSample: Int)?
        var offset = 12
        while offset + 8 <= bytes.count {
            let identifier = bytes[offset..<(offset + 4)]
            let size = Int(unsignedInteger(bytes, at: offset + 4, as: UInt32.self))
            let content = offset + 8
            if identifier == Data("fmt ".utf8) {
                guard size >= 16, content + 16 <= bytes.count else { return nil }
                let integerPCM: UInt16 = 1
                guard unsignedInteger(bytes, at: content, as: UInt16.self) == integerPCM else { return nil }
                format = (Int(unsignedInteger(bytes, at: content + 2, as: UInt16.self)),
                          Int(unsignedInteger(bytes, at: content + 4, as: UInt32.self)),
                          Int(unsignedInteger(bytes, at: content + 14, as: UInt16.self)))
            } else if identifier == Data("data".utf8) {
                guard let format else { return nil }
                return WavFormat(channelCount: format.channelCount, bitsPerSample: format.bitsPerSample,
                                 sampleRate: format.sampleRate, dataOffset: content)
            }
            offset = content + size + size % 2  // chunks are padded to an even length
        }
        return nil
    }

    /// The largest sample magnitude, as a fraction of full scale (0 = digital silence, 1 = full scale).
    public static func peak(ofInt16Samples bytes: Data) -> Double {
        var largestMagnitude: UInt16 = 0
        bytes.withUnsafeBytes { buffer in
            for index in stride(from: 0, to: buffer.count - 1, by: 2) {
                let sample = Int16(littleEndian: buffer.loadUnaligned(fromByteOffset: index, as: Int16.self))
                largestMagnitude = max(largestMagnitude, sample.magnitude)
            }
        }
        return Double(largestMagnitude) / 32768
    }

    /// Decibels relative to full scale (dBFS): 0 at full scale, −6 at half, −∞ for digital silence.
    public static func decibels(ofPeak peak: Double) -> Double {
        peak > 0 ? 20 * log10(peak) : -.infinity
    }

    private static func unsignedInteger<T: FixedWidthInteger>(_ bytes: Data, at offset: Int, as type: T.Type) -> T {
        bytes.withUnsafeBytes { T(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: T.self)) }
    }
}
