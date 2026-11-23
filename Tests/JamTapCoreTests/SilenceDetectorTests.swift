import Testing
@testable import JamTapCore

@Test func soundIsNeverSilentTooLong() {
    var detector = SilenceDetector(silenceBelowDecibels: -60, warnAfterSeconds: 10)
    for second in 0...30 { detector.observe(peakDecibels: -20, atSecond: Double(second)) }
    #expect(!detector.isSilentTooLong)
}

@Test func warnsOnlyAfterTheFullSilentStretch() {
    var detector = SilenceDetector(silenceBelowDecibels: -60, warnAfterSeconds: 10)
    for second in 0...9 { detector.observe(peakDecibels: -.infinity, atSecond: Double(second)) }
    #expect(!detector.isSilentTooLong)
    detector.observe(peakDecibels: -.infinity, atSecond: 10)
    #expect(detector.isSilentTooLong)
}

@Test func soundEndsTheWarningAndRestartsTheCount() {
    var detector = SilenceDetector(silenceBelowDecibels: -60, warnAfterSeconds: 10)
    for second in 0...12 { detector.observe(peakDecibels: -80, atSecond: Double(second)) }
    #expect(detector.isSilentTooLong)
    detector.observe(peakDecibels: -30, atSecond: 13)
    #expect(!detector.isSilentTooLong)
    for second in 14...22 { detector.observe(peakDecibels: -80, atSecond: Double(second)) }
    #expect(!detector.isSilentTooLong)
    for second in 23...24 { detector.observe(peakDecibels: -80, atSecond: Double(second)) }
    #expect(detector.isSilentTooLong)
}

@Test func aLevelExactlyAtTheThresholdCountsAsSound() {
    var detector = SilenceDetector(silenceBelowDecibels: -60, warnAfterSeconds: 10)
    for second in 0...30 { detector.observe(peakDecibels: -60, atSecond: Double(second)) }
    #expect(!detector.isSilentTooLong)
}
