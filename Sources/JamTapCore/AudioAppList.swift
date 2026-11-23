/// One process that has an audio connection: a row of `catap list-apps --all`.
/// An app can have several, for instance a browser with one helper process per window.
public struct AudioProcess: Equatable, Sendable {
    public let name: String
    public let bundleIdentifier: String
    public let processID: Int
    /// True when the process is producing sound right now.
    public let isPlaying: Bool

    public init(name: String, bundleIdentifier: String, processID: Int, isPlaying: Bool) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.processID = processID
        self.isPlaying = isPlaying
    }
}

/// An app as the user chooses it in the menu: all audio processes that share one name.
public struct AudioApp: Equatable, Sendable {
    public let name: String
    /// True when any of the app's processes is producing sound right now.
    public let isPlaying: Bool

    public init(name: String, isPlaying: Bool) {
        self.name = name
        self.isPlaying = isPlaying
    }
}

public enum AudioAppList {
    /// The rows of the table that `catap list-apps --all` prints.
    /// Each row is `[♪] <name, may contain spaces> <bundle id> <audio id> <process id>`.
    public static func parseProcesses(catapListing: String) -> [AudioProcess] {
        catapListing.split(separator: "\n").compactMap { line in
            var fields = line.split(separator: " ").map(String.init)
            let isPlaying = fields.first == "♪"
            if isPlaying { fields.removeFirst() }
            guard fields.count >= 4, let processID = Int(fields[fields.count - 1]), Int(fields[fields.count - 2]) != nil
            else { return nil }  // header, rule, or a row without a name
            return AudioProcess(name: fields[0..<(fields.count - 3)].joined(separator: " "),
                                bundleIdentifier: fields[fields.count - 3], processID: processID, isPlaying: isPlaying)
        }
    }

    /// One app per process name, playing apps first, then by name.
    public static func apps(of processes: [AudioProcess]) -> [AudioApp] {
        Dictionary(grouping: processes, by: \.name)
            .map { name, sameName in AudioApp(name: name, isPlaying: sameName.contains(where: \.isPlaying)) }
            .sorted {
                $0.isPlaying != $1.isPlaying
                    ? $0.isPlaying
                    : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    /// The process IDs of the chosen apps, in the order of the listing. `catap` rejects an app name
    /// that matches several processes, so apps are passed to it as process IDs.
    public static func processIDs(ofApps chosenNames: [String], among processes: [AudioProcess]) -> [Int] {
        processes.filter { chosenNames.contains($0.name) }.map(\.processID)
    }
}
