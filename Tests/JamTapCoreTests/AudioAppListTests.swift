import Testing
@testable import JamTapCore

private let listing = """
Status Name                           Bundle ID                                Audio ID   PID     
--------------------------------------------------------------------------------------------
   Amphetamine                    com.if.Amphetamine                       168        1612    
   BetterTouchToolAppleScriptRunner com.hegenberg.BetterTouchToolAppleScriptRunner 178        88858   
   Koushi Graphics and Media      com.apple.WebKit.GPU                     194        5467    
♪  Koushi Graphics and Media      com.apple.WebKit.GPU                     184        49877   
♪  Logic Pro                      com.apple.logic10                        201        777     
"""

@Test func parsesOneProcessPerRowWithNamesThatContainSpaces() {
    let processes = AudioAppList.parseProcesses(catapListing: listing)
    #expect(processes.map(\.name) == ["Amphetamine", "BetterTouchToolAppleScriptRunner",
                                      "Koushi Graphics and Media", "Koushi Graphics and Media", "Logic Pro"])
    #expect(processes.map(\.processID) == [1612, 88858, 5467, 49877, 777])
    #expect(processes.map(\.isPlaying) == [false, false, false, true, true])
    #expect(processes.last?.bundleIdentifier == "com.apple.logic10")
}

@Test func anEmptyOrHeaderOnlyListingHasNoProcesses() {
    #expect(AudioAppList.parseProcesses(catapListing: "").isEmpty)
    #expect(AudioAppList.parseProcesses(catapListing: "Status Name Bundle ID Audio ID PID\n-----\n").isEmpty)
}

@Test func appsAreListedOncePlayingOnesFirst() {
    let apps = AudioAppList.apps(of: AudioAppList.parseProcesses(catapListing: listing))
    #expect(apps.map(\.name) == ["Koushi Graphics and Media", "Logic Pro", "Amphetamine", "BetterTouchToolAppleScriptRunner"])
}

@Test func anAppIsPlayingWhenAnyOfItsProcessesIs() {
    let apps = AudioAppList.apps(of: AudioAppList.parseProcesses(catapListing: listing))
    #expect(apps.first { $0.name == "Koushi Graphics and Media" }?.isPlaying == true)
    #expect(apps.first { $0.name == "Amphetamine" }?.isPlaying == false)
}

@Test func aChosenAppStandsForAllItsProcesses() {
    let processes = AudioAppList.parseProcesses(catapListing: listing)
    #expect(AudioAppList.processIDs(ofApps: ["Koushi Graphics and Media", "Logic Pro", "Not Running"], among: processes)
        == [5467, 49877, 777])
    #expect(AudioAppList.processIDs(ofApps: ["Not Running"], among: processes).isEmpty)
}
