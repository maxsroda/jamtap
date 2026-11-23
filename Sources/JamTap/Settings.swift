import Foundation
import JamTapCore

/// The user's choices, kept in the app's preferences (`defaults read pl.maksymiliansroda.jamtap`).
enum Settings {
    enum SourceKind: String, CaseIterable {
        case systemMix, mixOfApps, separateTrackPerApp
    }

    private static let defaults = UserDefaults.standard

    static var recordingsDirectory: URL {
        get {
            defaults.string(forKey: "recordingsDirectory").map { URL(fileURLWithPath: $0, isDirectory: true) }
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/Jams/Solo", isDirectory: true)
        }
        set { defaults.set(newValue.path, forKey: "recordingsDirectory") }
    }

    static var sourceKind: SourceKind {
        get { defaults.string(forKey: "sourceKind").flatMap(SourceKind.init) ?? .systemMix }
        set { defaults.set(newValue.rawValue, forKey: "sourceKind") }
    }

    /// Names of the apps to record when the source is not the system mix.
    static var chosenApps: [String] {
        get { defaults.stringArray(forKey: "chosenApps") ?? [] }
        set { defaults.set(newValue, forKey: "chosenApps") }
    }

    static var source: RecordingSource {
        switch sourceKind {
        case .systemMix: .systemMix
        case .mixOfApps: .mixOfApps(chosenApps)
        case .separateTrackPerApp: .separateTrackPerApp(chosenApps)
        }
    }

    /// A recording stops by itself after this many minutes; 0 means never.
    static var autoStopMinutes: Int {
        get { defaults.integer(forKey: "autoStopMinutes") }
        set { defaults.set(newValue, forKey: "autoStopMinutes") }
    }
}
