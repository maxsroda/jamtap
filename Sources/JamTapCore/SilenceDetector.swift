/// Decides when a recording has been silent for so long that the user should be warned,
/// for instance because the sound is routed somewhere the capture does not hear.
public struct SilenceDetector: Sendable {
    public let silenceBelowDecibels: Double
    public let warnAfterSeconds: Double
    private var silentSinceSecond: Double?
    private var latestSecond: Double = 0

    /// - Parameters:
    ///   - silenceBelowDecibels: a peak level below this (in dBFS) counts as silence.
    ///   - warnAfterSeconds: how long the silence must last before `isSilentTooLong`.
    public init(silenceBelowDecibels: Double = -60, warnAfterSeconds: Double = 10) {
        self.silenceBelowDecibels = silenceBelowDecibels
        self.warnAfterSeconds = warnAfterSeconds
    }

    /// Reports the peak level of the audio captured up to `second` (seconds since the recording started).
    public mutating func observe(peakDecibels: Double, atSecond second: Double) {
        latestSecond = second
        if peakDecibels >= silenceBelowDecibels {
            silentSinceSecond = nil
        } else if silentSinceSecond == nil {
            silentSinceSecond = second
        }
    }

    public var isSilentTooLong: Bool {
        guard let silentSinceSecond else { return false }
        return latestSecond - silentSinceSecond >= warnAfterSeconds
    }
}
