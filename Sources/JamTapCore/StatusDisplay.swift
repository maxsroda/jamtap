/// What the menu bar icon tells the user.
public enum StatusIconKind: String, CaseIterable, Sendable {
    /// Not recording: a translucent guitar.
    case idle
    /// Recording: a solid guitar with notes flying off it.
    case recording
    /// Recording, but the capture has been silent for a while: a solid guitar with a warning mark.
    case recordingSilent
    /// Not recording, and an earlier take is still being converted to MP3.
    case converting
    /// Not recording, and the last take failed or is silent: a translucent guitar with a warning mark.
    /// The menu says what went wrong.
    case problem

    /// - Parameter hasUnseenProblem: the last take went wrong and the user has not opened the menu since.
    public static func showing(isRecording: Bool, isSilentTooLong: Bool, conversionsInProgress: Int,
                               hasUnseenProblem: Bool) -> StatusIconKind {
        if isRecording { return isSilentTooLong ? .recordingSilent : .recording }
        if hasUnseenProblem { return .problem }
        return conversionsInProgress > 0 ? .converting : .idle
    }
}

public enum ElapsedTime {
    /// `2:13`, or `1:02:13` from one hour on.
    public static func text(seconds: Double) -> String {
        let total = Int(seconds)
        let (hours, minutes, secondsPart) = (total / 3600, total / 60 % 60, total % 60)
        let twoDigits = { (value: Int) in value < 10 ? "0\(value)" : "\(value)" }
        return hours > 0 ? "\(hours):\(twoDigits(minutes)):\(twoDigits(secondsPart))" : "\(minutes):\(twoDigits(secondsPart))"
    }
}
