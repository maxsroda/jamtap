import Foundation
import Testing
@testable import JamTapCore

private let take = Take(directory: URL(fileURLWithPath: "/Jams/Solo"), name: "jam-2026-11-02_2338")

private let processes = [
    AudioProcess(name: "Browser Helper", bundleIdentifier: "com.example.helper", processID: 11, isPlaying: false),
    AudioProcess(name: "Browser Helper", bundleIdentifier: "com.example.helper", processID: 12, isPlaying: true),
    AudioProcess(name: "Logic Pro", bundleIdentifier: "com.apple.logic10", processID: 20, isPlaying: true),
]

@Test func takeFilesShareTheTakeName() {
    #expect(take.wav.path == "/Jams/Solo/jam-2026-11-02_2338.wav")
    #expect(take.mp3.path == "/Jams/Solo/jam-2026-11-02_2338.mp3")
    #expect(take.trackDirectory.path == "/Jams/Solo/jam-2026-11-02_2338")
}

@Test func systemMixNeedsNoChosenApp() {
    #expect(RecordingSource.resolved(kind: .systemMix, chosenApps: [], processes: []) == .systemMix)
}

@Test func chosenAppsBecomeTheirProcesses() {
    #expect(RecordingSource.resolved(kind: .mixOfApps, chosenApps: ["Logic Pro", "Browser Helper"], processes: processes)
        == .mixOfProcesses([11, 12, 20]))
    #expect(RecordingSource.resolved(kind: .separateTrackPerApp, chosenApps: ["Logic Pro"], processes: processes)
        == .separateTrackPerProcess([20]))
}

@Test func nothingToRecordWhenNoChosenAppHasAudioOpen() {
    #expect(RecordingSource.resolved(kind: .mixOfApps, chosenApps: [], processes: processes) == nil)
    #expect(RecordingSource.resolved(kind: .separateTrackPerApp, chosenApps: ["Not Running"], processes: processes) == nil)
}

@Test func systemMixRecordsEverythingIntoOneWav() {
    #expect(CaptureCommand.catapArguments(source: .systemMix, take: take)
        == ["record", "--system", "-o", "/Jams/Solo/jam-2026-11-02_2338.wav"])
}

@Test func mixOfProcessesNamesEachProcess() {
    #expect(CaptureCommand.catapArguments(source: .mixOfProcesses([11, 20]), take: take)
        == ["record", "-o", "/Jams/Solo/jam-2026-11-02_2338.wav", "--pid", "11", "--pid", "20"])
}

@Test func separateTracksGoIntoADirectoryNamedAfterTheTake() {
    #expect(CaptureCommand.catapArguments(source: .separateTrackPerProcess([11, 20]), take: take)
        == ["record-multitrack", "-o", "/Jams/Solo/jam-2026-11-02_2338", "--pid", "11", "--pid", "20"])
}

@Test func aSingleProcessIsRecordedAsOneFileBecauseSeparateTracksNeedTwo() {
    #expect(CaptureCommand.catapArguments(source: .separateTrackPerProcess([20]), take: take)
        == CaptureCommand.catapArguments(source: .mixOfProcesses([20]), take: take))
    #expect(CaptureCommand.output(source: .separateTrackPerProcess([20]), take: take) == .singleWav(take.wav))
}

@Test func outputIsOneFileUnlessTracksAreSeparate() {
    #expect(CaptureCommand.output(source: .systemMix, take: take) == .singleWav(take.wav))
    #expect(CaptureCommand.output(source: .mixOfProcesses([11, 20]), take: take) == .singleWav(take.wav))
    #expect(CaptureCommand.output(source: .separateTrackPerProcess([11, 20]), take: take) == .trackDirectory(take.trackDirectory))
}

@Test func ffmpegConvertsWavToVariableBitrateMp3() {
    let wav = URL(fileURLWithPath: "/Jams/a.wav"), mp3 = URL(fileURLWithPath: "/Jams/a.mp3")
    #expect(CaptureCommand.ffmpegArguments(wav: wav, mp3: mp3)
        == ["-hide_banner", "-loglevel", "error", "-nostdin", "-i", "/Jams/a.wav",
            "-codec:a", "libmp3lame", "-q:a", "2", "/Jams/a.mp3"])
}

@Test func catapHasStartedOnceItSaysItIsRecording() {
    let settingUp = "Recording from: Logic Pro (PID: 20, Audio ID: 201)\nOutput: /Jams/a.wav\nCreated tap (ID: 196)\n"
    #expect(!CaptureCommand.catapHasStartedRecording(output: ""))
    #expect(!CaptureCommand.catapHasStartedRecording(output: settingUp))
    #expect(CaptureCommand.catapHasStartedRecording(output: settingUp + "Recording... (Ctrl+C to stop)\n"))
    #expect(CaptureCommand.catapHasStartedRecording(output: "Recording global process-output mix\nRecording for 20.0 seconds... (Ctrl+C to stop early)\n"))
}
