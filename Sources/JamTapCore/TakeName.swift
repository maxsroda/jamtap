import Foundation

/// Names of takes (one recording session = one take), without directory or file extension.
/// A take is named after its start time, `jam-2026-11-02_2338`, optionally numbered when a second
/// take starts in the same minute (`…_2338-2`) and optionally followed by a label (`…_2338 slow blues`).
public enum TakeName {
    // A computed property: a stored `Regex` is not `Sendable`, so it cannot be a shared constant.
    private static var timestampPrefix: Regex<(Substring, Substring?)> { /^jam-\d{4}-\d{2}-\d{2}_\d{4}(-\d+)?/ }

    public static func timestamped(at date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(format: "jam-%04d-%02d-%02d_%02d%02d",
                      parts.year!, parts.month!, parts.day!, parts.hour!, parts.minute!)
    }

    /// `name` itself, or `name-2`, `name-3`, … : the first that no existing take uses.
    /// A labelled take uses the name in front of its label.
    public static func firstUnused(_ name: String, among existingNames: Set<String>) -> String {
        let usedNames = Set(existingNames.map(withoutLabel))
        if !usedNames.contains(name) { return name }
        var number = 2
        while usedNames.contains("\(name)-\(number)") { number += 1 }
        return "\(name)-\(number)"
    }

    /// The name with `label` after its timestamp, replacing an earlier label. An empty label removes it.
    /// A name without a timestamp is replaced by the label as a whole.
    public static func labelled(_ name: String, with label: String) -> String {
        let cleanLabel = label
            .replacing(/[\/:]/, with: "-")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard let timestamp = name.prefixMatch(of: timestampPrefix) else {
            return cleanLabel.isEmpty ? name : cleanLabel
        }
        return cleanLabel.isEmpty ? String(timestamp.0) : "\(timestamp.0) \(cleanLabel)"
    }

    private static func withoutLabel(_ name: String) -> String {
        name.prefixMatch(of: timestampPrefix).map { String($0.0) } ?? name
    }
}
