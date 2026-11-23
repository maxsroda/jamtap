import Testing
@testable import JamTapCore

@Test func elapsedTimeShowsMinutesAndSeconds() {
    #expect(ElapsedTime.text(seconds: 0) == "0:00")
    #expect(ElapsedTime.text(seconds: 7) == "0:07")
    #expect(ElapsedTime.text(seconds: 133.9) == "2:13")
    #expect(ElapsedTime.text(seconds: 59 * 60 + 59) == "59:59")
}

@Test func elapsedTimeShowsHoursOnceThereAreSome() {
    #expect(ElapsedTime.text(seconds: 3600) == "1:00:00")
    #expect(ElapsedTime.text(seconds: 3733) == "1:02:13")
}

@Test func iconShowsRecordingBeforeAnythingElse() {
    #expect(StatusIconKind.showing(isRecording: true, isSilentTooLong: false, conversionsInProgress: 2) == .recording)
    #expect(StatusIconKind.showing(isRecording: true, isSilentTooLong: true, conversionsInProgress: 0) == .recordingSilent)
}

@Test func iconShowsConvertingOnlyWhenNotRecording() {
    #expect(StatusIconKind.showing(isRecording: false, isSilentTooLong: false, conversionsInProgress: 1) == .converting)
    #expect(StatusIconKind.showing(isRecording: false, isSilentTooLong: false, conversionsInProgress: 0) == .idle)
    // A stale silence flag from the last recording does not matter once recording has stopped.
    #expect(StatusIconKind.showing(isRecording: false, isSilentTooLong: true, conversionsInProgress: 0) == .idle)
}
