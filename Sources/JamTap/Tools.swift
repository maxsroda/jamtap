import Foundation

/// Finds and runs the command-line tools JamTap depends on.
/// An app started from Finder does not get the shell's PATH, so the usual install directories are searched.
enum Tools {
    static var catap: URL? { locate("catap") }
    static var ffmpeg: URL? { locate("ffmpeg") }

    static let logDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/JamTap", isDirectory: true)

    private static func locate(_ name: String) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let pathDirectories = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        let directories = ["\(home)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "\(home)/bin"] + pathDirectories
        return directories
            .map { URL(fileURLWithPath: $0).appendingPathComponent(name) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// Starts `executable` with its output appended to a log file; `completion` runs on the main thread
    /// with the exit status. Returns the running process, or nil if it could not start.
    @discardableResult
    static func run(_ executable: URL, _ arguments: [String], logName: String,
                    completion: @escaping (_ exitStatus: Int32) -> Void) -> Process? {
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        let logFile = self.logFile(named: logName)
        FileManager.default.createFile(atPath: logFile.path, contents: nil)
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        if let log = try? FileHandle(forWritingTo: logFile) {
            process.standardOutput = log
            process.standardError = log
        }
        process.terminationHandler = { finished in
            DispatchQueue.main.async { completion(finished.terminationStatus) }
        }
        do {
            try process.run()
            return process
        } catch {
            return nil
        }
    }

    static func logFile(named logName: String) -> URL { logDirectory.appendingPathComponent(logName + ".log") }

    /// The last lines a tool printed, for an error message.
    static func lastOutput(logName: String) -> String {
        let text = (try? String(contentsOf: logFile(named: logName), encoding: .utf8)) ?? ""
        return text.split(separator: "\n").suffix(3).joined(separator: "\n")
    }
}
