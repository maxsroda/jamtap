import Foundation
import Testing
@testable import JamTapCore

private let take = Take(directory: URL(fileURLWithPath: "/Jams/Solo"), name: "jam-2026-11-02_2338")

@Test func takeFilesShareTheTakeName() {
    #expect(take.wav.path == "/Jams/Solo/jam-2026-11-02_2338.wav")
    #expect(take.mp3.path == "/Jams/Solo/jam-2026-11-02_2338.mp3")
    #expect(take.trackDirectory.path == "/Jams/Solo/jam-2026-11-02_2338")
}

@Test func systemMixRecordsEverythingIntoOneWav() {
    #expect(CaptureCommand.catapArguments(source: .systemMix, take: take)
        == ["record", "--system", "-o", "/Jams/Solo/jam-2026-11-02_2338.wav"])
}

@Test func mixOfAppsNamesTheAppsAfterTheOutput() {
    #expect(CaptureCommand.catapArguments(source: .mixOfApps(["Safari", "Logic Pro"]), take: take)
        == ["record", "-o", "/Jams/Solo/jam-2026-11-02_2338.wav", "--", "Safari", "Logic Pro"])
}

@Test func separateTracksGoIntoADirectoryNamedAfterTheTake() {
    #expect(CaptureCommand.catapArguments(source: .separateTrackPerApp(["Safari", "Logic Pro"]), take: take)
        == ["record-multitrack", "-o", "/Jams/Solo/jam-2026-11-02_2338", "--", "Safari", "Logic Pro"])
}

@Test func anEmptyAppListFallsBackToTheSystemMix() {
    let systemMix = CaptureCommand.catapArguments(source: .systemMix, take: take)
    #expect(CaptureCommand.catapArguments(source: .mixOfApps([]), take: take) == systemMix)
    #expect(CaptureCommand.catapArguments(source: .separateTrackPerApp([]), take: take) == systemMix)
}

@Test func outputIsOneFileUnlessTracksAreSeparate() {
    #expect(CaptureCommand.output(source: .systemMix, take: take) == .singleWav(take.wav))
    #expect(CaptureCommand.output(source: .mixOfApps(["Safari"]), take: take) == .singleWav(take.wav))
    #expect(CaptureCommand.output(source: .separateTrackPerApp(["Safari"]), take: take) == .trackDirectory(take.trackDirectory))
    #expect(CaptureCommand.output(source: .separateTrackPerApp([]), take: take) == .singleWav(take.wav))
}

@Test func ffmpegConvertsWavToVariableBitrateMp3() {
    let wav = URL(fileURLWithPath: "/Jams/a.wav"), mp3 = URL(fileURLWithPath: "/Jams/a.mp3")
    #expect(CaptureCommand.ffmpegArguments(wav: wav, mp3: mp3)
        == ["-hide_banner", "-loglevel", "error", "-nostdin", "-i", "/Jams/a.wav",
            "-codec:a", "libmp3lame", "-q:a", "2", "/Jams/a.mp3"])
}
