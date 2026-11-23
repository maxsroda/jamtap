import Foundation
import Testing
@testable import JamTapCore

private func warsawDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> (Date, Calendar) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
    let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    return (date, calendar)
}

@Test func timestampedNameMatchesTheShellFunction() {
    let (date, calendar) = warsawDate(2026, 11, 2, 23, 38)
    #expect(TakeName.timestamped(at: date, calendar: calendar) == "jam-2026-11-02_2338")
}

@Test func timestampedNamePadsSingleDigits() {
    let (date, calendar) = warsawDate(2026, 1, 5, 0, 7)
    #expect(TakeName.timestamped(at: date, calendar: calendar) == "jam-2026-01-05_0007")
}

@Test func firstUnusedKeepsAFreeName() {
    #expect(TakeName.firstUnused("jam-2026-11-02_2338", among: ["jam-2026-11-02_2337"]) == "jam-2026-11-02_2338")
}

@Test func firstUnusedNumbersASecondTakeInTheSameMinute() {
    #expect(TakeName.firstUnused("jam-2026-11-02_2338", among: ["jam-2026-11-02_2338"]) == "jam-2026-11-02_2338-2")
    #expect(TakeName.firstUnused("jam-2026-11-02_2338", among: ["jam-2026-11-02_2338", "jam-2026-11-02_2338-2"])
        == "jam-2026-11-02_2338-3")
}

@Test func firstUnusedTreatsALabelledTakeAsUsingItsTimestamp() {
    #expect(TakeName.firstUnused("jam-2026-11-02_2338", among: ["jam-2026-11-02_2338 slow blues"])
        == "jam-2026-11-02_2338-2")
}

@Test func labelIsAppendedAfterTheTimestamp() {
    #expect(TakeName.labelled("jam-2026-11-02_2338", with: "slow blues in A") == "jam-2026-11-02_2338 slow blues in A")
    #expect(TakeName.labelled("jam-2026-11-02_2338-2", with: "riff") == "jam-2026-11-02_2338-2 riff")
}

@Test func newLabelReplacesAnOldOne() {
    #expect(TakeName.labelled("jam-2026-11-02_2338 slow blues", with: "shuffle") == "jam-2026-11-02_2338 shuffle")
}

@Test func emptyLabelRemovesTheLabel() {
    #expect(TakeName.labelled("jam-2026-11-02_2338 slow blues", with: "  ") == "jam-2026-11-02_2338")
}

@Test func labelCannotContainPathSeparators() {
    #expect(TakeName.labelled("jam-2026-11-02_2338", with: " AC/DC: riff ") == "jam-2026-11-02_2338 AC-DC- riff")
}

@Test func labelReplacesANameWithoutTimestamp() {
    #expect(TakeName.labelled("12bar", with: "twelve bar") == "twelve bar")
    #expect(TakeName.labelled("12bar", with: "") == "12bar")
}
