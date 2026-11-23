import AppKit

if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--render-icons" {
    try StatusIcon.writePreviews(to: URL(fileURLWithPath: CommandLine.arguments[2]))
    exit(0)
}
