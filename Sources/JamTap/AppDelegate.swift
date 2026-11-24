import AppKit
import JamTapCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let recorder = Recorder()
    private let notifier = Notifier()
    private var toggleHotKey: HotKey?
    private let sourceMenu = NSMenu()
    private var isWaitingToQuit = false
    /// What went wrong with the last take, until the user has seen it in the menu.
    private var unseenProblem: String?
    private let toggleSignal = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
    private let terminateSignal = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            // Without a menu attached, the button reports both clicks: left opens the menu, right toggles.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageTrailing  // the elapsed time goes to the left of the icon
        }
        sourceMenu.delegate = self
        recorder.onChange = { [weak self] in self?.refreshStatusItem() }
        recorder.onTakeFinished = { [weak self] result in self?.report(result) }
        toggleHotKey = HotKey(keyCode: HotKey.toggleRecordingKeyCode, modifiers: HotKey.toggleRecordingModifiers) { [weak self] in
            self?.recorder.toggle()
        }
        // `pkill -USR1 -x JamTap` toggles recording too, for scripts and foot pedals.
        signal(SIGUSR1, SIG_IGN)  // the default action of the signal would end the app
        toggleSignal.setEventHandler { [weak self] in self?.recorder.toggle() }
        toggleSignal.resume()
        // `pkill JamTap` (SIGTERM) quits the way the menu does. By default the signal would end the app
        // at once and leave catap recording with nobody to stop it.
        signal(SIGTERM, SIG_IGN)
        terminateSignal.setEventHandler {
            // Not from inside this main-queue block: quitting waits for the take in a nested run loop, and
            // the take's completion handlers, queued on the main queue, could not run until the block returns.
            RunLoop.main.perform(inModes: [.common]) { NSApp.terminate(nil) }
        }
        terminateSignal.resume()
        notifier.requestPermission()
        refreshStatusItem()
    }

    /// Quitting while a take is being recorded or converted finishes that take first.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard recorder.isBusy else { return .terminateNow }
        isWaitingToQuit = true
        recorder.stop()
        return .terminateLater
    }

    // MARK: Status item

    private func refreshStatusItem() {
        guard let button = statusItem.button else { return }
        if recorder.isRecording { unseenProblem = nil }  // a new take replaces the news about the last one
        let kind = StatusIconKind.showing(isRecording: recorder.isRecording, isSilentTooLong: recorder.isSilentTooLong,
                                          conversionsInProgress: recorder.conversionsInProgress,
                                          hasUnseenProblem: unseenProblem != nil)
        button.image = StatusIcon.image(kind)
        let digitsOfEqualWidth = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
        button.attributedTitle = NSAttributedString(string: recorder.elapsedSeconds.map { ElapsedTime.text(seconds: $0) + " " } ?? "",
                                                    attributes: [.font: digitsOfEqualWidth])
        button.toolTip = switch kind {
        case .idle: "JamTap: right-click to record"
        case .recording: "JamTap: recording, right-click to stop"
        case .recordingSilent: "JamTap: recording, but nothing has been heard for a while"
        case .converting: "JamTap: converting the last take to MP3"
        case .problem: "JamTap: the last take went wrong, click to see why"
        }
        if isWaitingToQuit, !recorder.isBusy {
            NSApp.reply(toApplicationShouldTerminate: true)
        }
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        // Control-click is the one-button way to right-click.
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            recorder.toggle()
        } else {
            // Attach the menu only for this click, so that a right click keeps toggling.
            statusItem.menu = makeMenu()
            statusItem.button?.performClick(nil)  // returns when the menu has closed
            statusItem.menu = nil
            unseenProblem = nil  // the menu showed it
            refreshStatusItem()
        }
    }

    /// Tells the user how a take ended. A take that went wrong is reported by a notification and, in
    /// case notifications are off, by a warning mark on the icon with the reason in the menu.
    /// No alert window: a modal alert would stop the app from reacting to clicks until it is dismissed.
    private func report(_ result: TakeResult) {
        switch result {
        case .saved(let url):
            notifier.show(title: "Jam saved", body: url.lastPathComponent, file: url)
        case .savedSilent(let url):
            let advice = "\(url.lastPathComponent) contains only silence. If sound was playing, macOS has not allowed "
                + "JamTap to record it: allow JamTap under System Settings > Privacy & Security > "
                + "Screen & System Audio Recording, then quit and reopen JamTap."
            notifier.show(title: "Jam is silent", body: advice, file: url)
            unseenProblem = advice
        case .keptUnconverted(let url, let reason):
            notifier.show(title: "Jam saved as WAV", body: "\(url.lastPathComponent)\n\(reason)", file: url)
            unseenProblem = "\(url.lastPathComponent): \(reason)"
        case .failed(let reason):
            notifier.show(title: "JamTap could not record", body: reason, file: nil)
            unseenProblem = "Could not record. \(reason)"
        }
        refreshStatusItem()
    }

    // MARK: Menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        if let unseenProblem {
            // Menu items do not wrap, so the reason is laid out in lines of about 60 characters.
            var line = ""
            var lines: [String] = []
            for word in unseenProblem.split(whereSeparator: \.isWhitespace) {
                if !line.isEmpty, line.count + word.count >= 60 {
                    lines.append(line)
                    line = ""
                }
                line += (line.isEmpty ? "" : " ") + word
            }
            for (index, text) in (lines + [line]).enumerated() {
                let reason = NSMenuItem(title: (index == 0 ? "⚠ " : "     ") + text, action: nil, keyEquivalent: "")
                reason.isEnabled = false
                menu.addItem(reason)
            }
            menu.addItem(.separator())
        }
        let toggle = item(recorder.isRecording ? "Stop Recording" : "Start Recording", #selector(toggleRecording))
        if toggleHotKey != nil {  // shown only if the system-wide shortcut could be registered
            toggle.keyEquivalent = HotKey.toggleRecordingKeyEquivalent
            toggle.keyEquivalentModifierMask = [.control, .option, .command]
        }
        menu.addItem(toggle)
        menu.addItem(.separator())

        let source = NSMenuItem(title: "Record", action: nil, keyEquivalent: "")
        source.submenu = sourceMenu  // filled when it opens, see menuNeedsUpdate
        menu.addItem(source)

        let autoStop = NSMenuItem(title: "Stop Automatically", action: nil, keyEquivalent: "")
        autoStop.submenu = NSMenu()
        for (title, minutes) in [("Never", 0), ("After 15 Minutes", 15), ("After 30 Minutes", 30),
                                 ("After 1 Hour", 60), ("After 2 Hours", 120)] {
            let choice = item(title, #selector(chooseAutoStop(_:)))
            choice.tag = minutes
            choice.state = Settings.autoStopMinutes == minutes ? .on : .off
            autoStop.submenu?.addItem(choice)
        }
        menu.addItem(autoStop)
        menu.addItem(.separator())

        let recentTakes = self.recentTakes(limit: 5)
        let recent = NSMenuItem(title: "Recent Jams", action: nil, keyEquivalent: "")
        recent.submenu = NSMenu()
        for take in recentTakes {
            let play = item(take.deletingPathExtension().lastPathComponent, #selector(openTake(_:)))
            play.representedObject = take
            recent.submenu?.addItem(play)
        }
        recent.isEnabled = !recentTakes.isEmpty
        menu.addItem(recent)
        let rename = item("Rename Last Jam…", #selector(renameLastTake))
        rename.isEnabled = !recentTakes.isEmpty
        menu.addItem(rename)
        menu.addItem(.separator())

        let directory = Settings.recordingsDirectory
        let folderLabel = NSMenuItem(title: "Saves to " + (directory.path as NSString).abbreviatingWithTildeInPath,
                                     action: nil, keyEquivalent: "")
        folderLabel.isEnabled = false
        menu.addItem(folderLabel)
        menu.addItem(item("Open Folder in Finder", #selector(openRecordingsDirectory)))
        menu.addItem(item("Change Folder…", #selector(changeRecordingsDirectory)))
        menu.addItem(.separator())

        let launchAtLogin = item("Launch at Login", #selector(toggleLaunchAtLogin))
        launchAtLogin.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launchAtLogin)
        menu.addItem(NSMenuItem(title: "Quit JamTap", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    /// Fills the "Record" submenu when it opens, with the apps that have an audio connection right now.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === sourceMenu else { return }
        menu.removeAllItems()
        for (title, kind) in [("Everything the Mac Plays", SourceKind.systemMix),
                              ("Only the Checked Apps, Mixed", .mixOfApps),
                              ("Only the Checked Apps, One Track Each", .separateTrackPerApp)] {
            let choice = item(title, #selector(chooseSourceKind(_:)))
            choice.representedObject = kind.rawValue
            choice.state = Settings.sourceKind == kind ? .on : .off
            menu.addItem(choice)
        }
        menu.addItem(.separator())
        let chosenApps = Settings.chosenApps
        var apps = AudioAppList.apps(of: Tools.audioProcesses())
        // A chosen app stays listed while it is not running, so that it can be unchecked.
        for name in chosenApps where !apps.contains(where: { $0.name == name }) {
            apps.append(AudioApp(name: name, isPlaying: false))
        }
        if apps.isEmpty {
            let none = NSMenuItem(title: "No App Has Audio Open", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        }
        for app in apps {
            let choice = item(app.isPlaying ? "\(app.name)  ♪" : app.name, #selector(toggleApp(_:)))
            choice.representedObject = app.name
            choice.state = chosenApps.contains(app.name) ? .on : .off
            menu.addItem(choice)
        }
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func recentTakes(limit: Int) -> [URL] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isDirectoryKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: Settings.recordingsDirectory, includingPropertiesForKeys: keys)) ?? []
        let entries = urls.compactMap { url -> DirectoryEntry? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)), let modified = values.contentModificationDate else { return nil }
            return DirectoryEntry(url: url, modificationDate: modified, isDirectory: values.isDirectory ?? false)
        }
        return RecentTakes.mostRecent(among: entries, limit: limit)
    }

    // MARK: Menu actions

    @objc private func toggleRecording() { recorder.toggle() }

    @objc private func chooseSourceKind(_ sender: NSMenuItem) {
        guard let kind = (sender.representedObject as? String).flatMap(SourceKind.init) else { return }
        Settings.sourceKind = kind
    }

    @objc private func toggleApp(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        var chosenApps = Settings.chosenApps
        if let index = chosenApps.firstIndex(of: name) { chosenApps.remove(at: index) } else { chosenApps.append(name) }
        Settings.chosenApps = chosenApps
    }

    @objc private func chooseAutoStop(_ sender: NSMenuItem) { Settings.autoStopMinutes = sender.tag }

    @objc private func openTake(_ sender: NSMenuItem) {
        guard let take = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(take)
    }

    @objc private func openRecordingsDirectory() {
        let directory = Settings.recordingsDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }

    @objc private func changeRecordingsDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = Settings.recordingsDirectory
        panel.prompt = "Save Jams Here"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let chosen = panel.url {
            Settings.recordingsDirectory = chosen
        }
    }

    @objc private func renameLastTake() {
        guard let take = recentTakes(limit: 1).first else { return }
        let oldName = take.deletingPathExtension().lastPathComponent
        let alert = NSAlert()
        alert.messageText = "Label for \(oldName)"
        alert.informativeText = "The label goes after the date and time. Leave it empty to remove the label."
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let labelField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        labelField.stringValue = String(oldName.dropFirst(TakeName.labelled(oldName, with: "").count)).trimmingCharacters(in: .whitespaces)
        alert.accessoryView = labelField
        alert.window.initialFirstResponder = labelField
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let newName = TakeName.labelled(oldName, with: labelField.stringValue)
        guard newName != oldName else { return }
        var renamed = take.deletingLastPathComponent().appendingPathComponent(newName)
        if !take.pathExtension.isEmpty { renamed.appendPathExtension(take.pathExtension) }
        do {
            // moveItem refuses to replace an existing file, so no take is overwritten.
            try FileManager.default.moveItem(at: take, to: renamed)
        } catch {
            showAlert(title: "Could not rename the jam", text: error.localizedDescription)
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showAlert(title: "Could not change Launch at Login", text: error.localizedDescription)
        }
    }

    private func showAlert(title: String, text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
