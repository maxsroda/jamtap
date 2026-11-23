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

@Test func parsesNamesWithSpacesAndLongNames() {
    let apps = AudioAppList.parse(catapListing: listing)
    #expect(apps.map(\.name) == ["Koushi Graphics and Media", "Logic Pro", "Amphetamine", "BetterTouchToolAppleScriptRunner"])
}

@Test func anAppIsPlayingWhenAnyOfItsProcessesIs() {
    let apps = AudioAppList.parse(catapListing: listing)
    #expect(apps.first { $0.name == "Koushi Graphics and Media" }?.isPlaying == true)
    #expect(apps.first { $0.name == "Amphetamine" }?.isPlaying == false)
}

@Test func keepsTheBundleIdentifier() {
    let apps = AudioAppList.parse(catapListing: listing)
    #expect(apps.first { $0.name == "Logic Pro" }?.bundleIdentifier == "com.apple.logic10")
}

@Test func anEmptyOrHeaderOnlyListingHasNoApps() {
    #expect(AudioAppList.parse(catapListing: "").isEmpty)
    #expect(AudioAppList.parse(catapListing: "Status Name Bundle ID Audio ID PID\n-----\n").isEmpty)
}
