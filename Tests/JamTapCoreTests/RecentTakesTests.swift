import Foundation
import Testing
@testable import JamTapCore

private func entry(_ name: String, modifiedAt seconds: TimeInterval, isDirectory: Bool = false) -> DirectoryEntry {
    DirectoryEntry(url: URL(fileURLWithPath: "/Jams/Solo/" + name, isDirectory: isDirectory),
                   modificationDate: Date(timeIntervalSince1970: seconds), isDirectory: isDirectory)
}

@Test func newestTakesComeFirstAndTheListIsCapped() {
    let entries = (1...8).map { entry("jam-\($0).mp3", modifiedAt: Double($0)) }
    let recent = RecentTakes.mostRecent(among: entries, limit: 5)
    #expect(recent.map(\.lastPathComponent) == ["jam-8.mp3", "jam-7.mp3", "jam-6.mp3", "jam-5.mp3", "jam-4.mp3"])
}

@Test func onlyAudioFilesAndTrackDirectoriesAreTakes() {
    let entries = [
        entry("notes.txt", modifiedAt: 9),
        entry(".jam-1.wav.abc123.tmp", modifiedAt: 8),   // catap's file while it records
        entry(".DS_Store", modifiedAt: 7),
        entry("jam-3", modifiedAt: 6, isDirectory: true), // one WAV or MP3 per app
        entry("jam-2.wav", modifiedAt: 5),
        entry("jam-1.MP3", modifiedAt: 4),
    ]
    #expect(RecentTakes.mostRecent(among: entries, limit: 5).map(\.lastPathComponent) == ["jam-3", "jam-2.wav", "jam-1.MP3"])
}
