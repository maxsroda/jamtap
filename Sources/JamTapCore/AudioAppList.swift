/// An app that has an audio connection, as listed by `catap list-apps --all`.
public struct AudioApp: Equatable, Sendable {
    public let name: String
    public let bundleIdentifier: String
    /// True when the app is producing sound right now.
    public let isPlaying: Bool

    public init(name: String, bundleIdentifier: String, isPlaying: Bool) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.isPlaying = isPlaying
    }
}

public enum AudioAppList {
    /// Apps from the table that `catap list-apps --all` prints, one per name, playing apps first, then by name.
    /// Each row is `[♪] <name, may contain spaces> <bundle id> <audio id> <pid>`.
    public static func parse(catapListing: String) -> [AudioApp] {
        var appsByName: [String: AudioApp] = [:]
        for line in catapListing.split(separator: "\n") {
            var fields = line.split(separator: " ").map(String.init)
            let isPlaying = fields.first == "♪"
            if isPlaying { fields.removeFirst() }
            guard fields.count >= 4, Int(fields[fields.count - 1]) != nil, Int(fields[fields.count - 2]) != nil
            else { continue }  // header, rule, or a row without a name
            let name = fields[0..<(fields.count - 3)].joined(separator: " ")
            let app = AudioApp(name: name, bundleIdentifier: fields[fields.count - 3],
                               isPlaying: isPlaying || appsByName[name]?.isPlaying == true)
            appsByName[name] = app
        }
        return appsByName.values.sorted {
            $0.isPlaying != $1.isPlaying ? $0.isPlaying : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
