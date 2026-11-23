import AppKit

// `JamTap --render-icons <directory>` writes the menu bar icons as PNG files and exits.
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--render-icons" {
    try StatusIcon.writePreviews(to: URL(fileURLWithPath: CommandLine.arguments[2]))
    exit(0)
}

// `JamTap --render-app-icon <file.png>` writes the app icon and exits; the build script uses it.
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--render-app-icon" {
    try StatusIcon.writeAppIcon(to: URL(fileURLWithPath: CommandLine.arguments[2]))
    exit(0)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)  // no Dock icon, no main menu
application.run()
