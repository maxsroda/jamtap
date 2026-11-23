import Foundation

public struct DirectoryEntry: Equatable, Sendable {
    public let url: URL
    public let modificationDate: Date
    public let isDirectory: Bool

    public init(url: URL, modificationDate: Date, isDirectory: Bool) {
        self.url = url
        self.modificationDate = modificationDate
        self.isDirectory = isDirectory
    }
}

public enum RecentTakes {
    private static let audioExtensions: Set<String> = ["mp3", "wav"]

    /// The newest takes in the recordings directory, newest first: audio files, and directories
    /// (a take recorded with one track per app). Hidden files are skipped, which leaves out the
    /// temporary file `catap` writes while it records.
    public static func mostRecent(among entries: [DirectoryEntry], limit: Int) -> [URL] {
        entries
            .filter { !$0.url.lastPathComponent.hasPrefix(".") }
            .filter { $0.isDirectory || audioExtensions.contains($0.url.pathExtension.lowercased()) }
            .sorted { $0.modificationDate > $1.modificationDate }
            .prefix(limit)
            .map(\.url)
    }
}
