import Foundation
import Testing
@testable import JamTapCore

/// The header catap writes while recording: 16-bit stereo 48 kHz, "data" chunk at byte 36.
private func wavHeader(channelCount: UInt16 = 2, bitsPerSample: UInt16 = 16, formatTag: UInt16 = 1) -> Data {
    var data = Data("RIFF".utf8) + littleEndian(UInt32(0)) + Data("WAVE".utf8)
    data += Data("fmt ".utf8) + littleEndian(UInt32(16)) + littleEndian(formatTag) + littleEndian(channelCount)
    data += littleEndian(UInt32(48000)) + littleEndian(UInt32(48000 * UInt32(channelCount) * UInt32(bitsPerSample / 8)))
    data += littleEndian(channelCount * bitsPerSample / 8) + littleEndian(bitsPerSample)
    data += Data("data".utf8) + littleEndian(UInt32(0))
    return data
}

private func littleEndian<T: FixedWidthInteger>(_ value: T) -> Data {
    withUnsafeBytes(of: value.littleEndian) { Data($0) }
}

private func samples(_ values: [Int16]) -> Data {
    values.reduce(into: Data()) { $0 += littleEndian($1) }
}

@Test func findsWhereTheSamplesStart() {
    let format = WavLevel.parseHeader(wavHeader())
    #expect(format == WavFormat(channelCount: 2, bitsPerSample: 16, sampleRate: 48000, dataOffset: 44))
}

@Test func skipsChunksBeforeTheSamples() {
    var header = wavHeader()
    let filler = Data("FLLR".utf8) + littleEndian(UInt32(3)) + Data([0, 0, 0, 0])  // odd size is padded to even
    header.insert(contentsOf: filler, at: 36)
    #expect(WavLevel.parseHeader(header)?.dataOffset == 44 + 12)
}

@Test func anIncompleteOrForeignHeaderHasNoFormat() {
    #expect(WavLevel.parseHeader(wavHeader().prefix(30)) == nil)
    #expect(WavLevel.parseHeader(Data("not a wav file at all, just some text bytes here".utf8)) == nil)
    #expect(WavLevel.parseHeader(wavHeader(formatTag: 3)) == nil)  // floating-point samples are not read
}

@Test func peakIsTheLargestMagnitudeAsAFractionOfFullScale() {
    #expect(WavLevel.peak(ofInt16Samples: samples([0, 100, -16384, 5])) == 0.5)
    #expect(WavLevel.peak(ofInt16Samples: samples([Int16.min])) == 1.0)
    #expect(WavLevel.peak(ofInt16Samples: samples([0, 0])) == 0)
    #expect(WavLevel.peak(ofInt16Samples: Data()) == 0)
}

@Test func peakIgnoresATrailingHalfSample() {
    #expect(WavLevel.peak(ofInt16Samples: samples([0, 8192]) + Data([0xFF])) == 0.25)
}

@Test func decibelsRelativeToFullScale() {
    #expect(WavLevel.decibels(ofPeak: 1.0) == 0)
    #expect(abs(WavLevel.decibels(ofPeak: 0.5) - -6.0206) < 1e-3)
    #expect(WavLevel.decibels(ofPeak: 0) == -.infinity)
}

@Test func peakOfAWholeFileSkipsTheHeader() throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("jamtap-test-\(UUID().uuidString).wav")
    defer { try? FileManager.default.removeItem(at: file) }
    try (wavHeader() + samples([0, 0, -8192, 0])).write(to: file)
    #expect(WavLevel.peak(ofFile: file) == 0.25)
    try (wavHeader() + samples([0, 0, 0, 0])).write(to: file)
    #expect(WavLevel.peak(ofFile: file) == 0)
}

@Test func peakOfAnUnreadableFileIsUnknown() {
    #expect(WavLevel.peak(ofFile: URL(fileURLWithPath: "/nonexistent/take.wav")) == nil)
}
