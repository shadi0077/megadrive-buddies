import AppKit
import ServiceManagement

enum BuddySize: CGFloat, CaseIterable {
    case small = 0.85, medium = 1.15, large = 1.6

    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var cast: Cast!
    private var statusItem: NSStatusItem!

    private let defaults = UserDefaults.standard
    private var size: BuddySize = .medium
    private var liveliness: Liveliness = .occasional
    /// This app's own level, nothing to do with the system volume.
    private var volume: Float = 0.8

    func applicationDidFinishLaunching(_ note: Notification) {
        size = BuddySize(rawValue: CGFloat(defaults.double(forKey: "size"))) ?? .medium
        liveliness = Liveliness(rawValue: defaults.object(forKey: "liveliness") as? Int ?? 1)
            ?? .occasional
        volume = Float(defaults.object(forKey: "volume") as? Double ?? 0.8)

        cast = Cast(scale: size.rawValue)
        guard !cast.buddies.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Nobody could be found."
            alert.informativeText = "The character sprites are missing from the app bundle."
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        cast.liveliness = liveliness

        for buddy in cast.buddies {
            restoreSound(for: buddy)
            buddy.window.onRightClick = { [weak self] event in
                self?.popUpMenu(with: event, for: buddy)
            }
        }

        buildStatusItem()

        // Who was out last time. First run gets Axel on his own — eleven
        // strangers at once is a lot.
        var wanted = defaults.array(forKey: "onStage") as? [String] ?? ["axel"]
        wanted = wanted.filter { cast.buddy($0) != nil }
        if wanted.isEmpty, let first = cast.buddies.first?.id { wanted = [first] }
        cast.showAll(wanted) { [weak self] id in
            self?.defaults.string(forKey: "origin.\(id)").map(NSPointFromString)
                .flatMap { self?.onAScreen($0) }
        }

        // Debugging hook: BUDDY_TURN=fight walks two of them together and
        // starts a scrap, rather than waiting for the idle rotation.
        if ProcessInfo.processInfo.environment["BUDDY_TURN"] == "fight" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.cast.gatherAndSpar()
            }
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func applicationWillTerminate(_ note: Notification) {
        defaults.set(cast.onScreen.map(\.id), forKey: "onStage")
        for buddy in cast.onScreen {
            defaults.set(NSStringFromPoint(buddy.window.frame.origin),
                         forKey: "origin.\(buddy.id)")
        }
        cast.buddies.forEach { $0.stop() }
    }

    @objc private func screensChanged() { cast.clampAll() }

    private func restoreSound(for buddy: Buddy) {
        buddy.brain.sounds?.volume = volume
        buddy.brain.sounds?.isEnabled = defaults.object(forKey: "sound") as? Bool ?? true
    }

    // MARK: - Menu

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = statusIcon()
        statusItem.button?.toolTip = Product.current.name
        // Without this the item has no stable identity between launches, so
        // macOS (and menu-bar managers like Bartender) can't remember where the
        // user put it or whether they chose to show it.
        statusItem.autosaveName = "MegaDriveStatusItem"
        statusItem.menu = makeMenu()
    }

    /// Whoever is out, in miniature.
    ///
    /// The sheets that have portrait art end with it, and a portrait makes a
    /// far better menu-bar glyph than any action frame — an idle sprite
    /// flattens into an unreadable blob at 18pt. Falls back to an SF Symbol so
    /// the item is never blank, which on a menu-bar-only app would mean no way
    /// in at all.
    private func statusIcon() -> NSImage? {
        let heroes = [("axel", 157), ("blaze", 181), ("max", 145), ("skate", 88),
                      ("adam", 0), ("axel1", 0), ("blaze1", 0),
                      ("galsia", 0), ("donovan", 0), ("eagle", 0), ("slum", 12)]
        for (id, frame) in heroes where cast.buddy(id)?.isVisible == true {
            if let icon = cast.buddy(id)?.store.menuBarIcon(frame: frame, height: 18) {
                return icon
            }
        }
        if let axel = cast.buddy("axel")?.store.menuBarIcon(frame: 157, height: 18) {
            return axel
        }
        for name in ["figure.walk", "person.fill"] {
            if let img = NSImage(systemSymbolName: name, accessibilityDescription: "Buddies") {
                img.isTemplate = true
                return img
            }
        }
        return nil
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let present = cast.onScreen

        menu.addItem(item("Do Something", #selector(sayHello)))
        if present.count > 1 {
            menu.addItem(item("Let Them Fight", #selector(haveThemFight)))
        }
        menu.addItem(item("Do a Trick", #selector(doTrick)))
        menu.addItem(.separator())

        // Who's out.
        let who = NSMenuItem(title: "Who's Here", action: nil, keyEquivalent: "")
        let whoMenu = NSMenu()
        for buddy in cast.buddies {
            let mi = item(buddy.brain.displayName, #selector(toggleCharacter(_:)))
            mi.representedObject = buddy.id
            mi.state = buddy.isVisible ? .on : .off
            whoMenu.addItem(mi)
        }
        who.submenu = whoMenu
        menu.addItem(who)

        // Per-character controls, for whoever is out.
        for buddy in cast.buddies where buddy.isVisible {
            menu.addItem(characterMenu(for: buddy))
        }
        menu.addItem(.separator())

        let pace = NSMenuItem(title: "Liveliness", action: nil, keyEquivalent: "")
        let paceMenu = NSMenu()
        for level in Liveliness.allCases {
            let mi = item(level.title, #selector(setLiveliness(_:)))
            mi.representedObject = level.rawValue
            mi.state = level == liveliness ? .on : .off
            paceMenu.addItem(mi)
        }
        pace.submenu = paceMenu
        menu.addItem(pace)

        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for s in BuddySize.allCases {
            let mi = item(s.title, #selector(setSize(_:)))
            mi.representedObject = s.rawValue
            mi.state = s == size ? .on : .off
            sizeMenu.addItem(mi)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        let soundOn = cast.buddies.first?.brain.sounds?.isEnabled ?? true
        menu.addItem(item(soundOn ? "Mute Sounds" : "Unmute Sounds",
                          #selector(toggleSound)))

        // Their own level, not the system's.
        let volumeItem = NSMenuItem()
        volumeItem.view = VolumeSliderView(value: volume) { [weak self] level in
            self?.setVolume(level)
        }
        volumeItem.isEnabled = soundOn
        menu.addItem(volumeItem)

        let login = item("Open at Login", #selector(toggleLoginItem))
        login.state = loginEnabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item("About", #selector(showAbout)))
        menu.addItem(item("Quit", #selector(quit), key: "q"))
        return menu
    }

    private func characterMenu(for buddy: Buddy) -> NSMenuItem {
        let root = NSMenuItem(title: buddy.brain.displayName, action: nil, keyEquivalent: "")
        let sub = NSMenu()

        let come = item("Come Here", #selector(comeHere(_:)))
        come.representedObject = buddy.id
        sub.addItem(come)

        let away = item("Send Away", #selector(sendAway(_:)))
        away.representedObject = buddy.id
        sub.addItem(away)

        root.submenu = sub
        return root
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: action, keyEquivalent: key)
        mi.target = self
        return mi
    }

    private func refreshMenu() {
        statusItem.menu = makeMenu()
        statusItem.button?.image = statusIcon()
    }

    private func popUpMenu(with event: NSEvent, for buddy: Buddy) {
        NSMenu.popUpContextMenu(makeMenu(), with: event, for: buddy.window.buddyView)
    }

    // MARK: - Actions

    /// Whoever should handle a general request: a random character who's free.
    private func anyone() -> Brain? {
        let free = cast.onScreen.filter { $0.brain.isAvailable }
        return (free.randomElement() ?? cast.onScreen.randomElement())?.brain
    }

    @objc private func sayHello() {
        for buddy in cast.onScreen where buddy.brain.isAvailable {
            buddy.brain.greet()
        }
    }

    @objc private func doTrick() { anyone()?.doATrick() }
    @objc private func haveThemFight() { cast.gatherAndSpar() }

    @objc private func comeHere(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        cast.buddy(id)?.brain.comeHere()
    }

    @objc private func sendAway(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        cast.hide(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.refreshMenu()
        }
    }

    @objc private func toggleCharacter(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let buddy = cast.buddy(id) else { return }
        if buddy.isVisible {
            cast.hide(id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.refreshMenu()
            }
        } else {
            let saved = defaults.string(forKey: "origin.\(id)").map(NSPointFromString)
            cast.show(id, at: saved.flatMap(onAScreen) )
            refreshMenu()
        }
        defaults.set(cast.buddies.filter(\.isVisible).map(\.id) + [id], forKey: "onStage")
        defaults.set(cast.onScreen.map(\.id), forKey: "onStage")
    }

    /// Only reuse a saved position if that part of the desktop still exists.
    private func onAScreen(_ point: NSPoint) -> NSPoint? {
        NSScreen.screens.contains {
            $0.visibleFrame.insetBy(dx: -40, dy: -40).contains(point)
        } ? point : nil
    }

    @objc private func setLiveliness(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? Int,
              let level = Liveliness(rawValue: raw) else { return }
        liveliness = level
        cast.liveliness = level
        defaults.set(raw, forKey: "liveliness")
        refreshMenu()
    }

    @objc private func setSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? CGFloat,
              let s = BuddySize(rawValue: raw) else { return }
        size = s
        defaults.set(Double(raw), forKey: "size")
        cast.resize(to: raw)
        refreshMenu()
    }

    private func setVolume(_ level: Float) {
        volume = min(max(level, 0), 1)
        for buddy in cast.buddies {
            buddy.brain.sounds?.volume = volume
        }
        defaults.set(Double(volume), forKey: "volume")
        // Deliberately not rebuilding the menu: that would tear the slider out
        // from under the pointer mid-drag.
    }

    @objc private func toggleSound() {
        let on = !(cast.buddies.first?.brain.sounds?.isEnabled ?? true)
        for buddy in cast.buddies {
            buddy.brain.sounds?.isEnabled = on
            buddy.brain.sounds?.volume = volume
            if !on { buddy.brain.sounds?.stop() }
        }
        defaults.set(on, forKey: "sound")
        refreshMenu()
    }

    // MARK: - Login item

    private var loginEnabled: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    @objc private func toggleLoginItem() {
        // Pre-Ventura there is no per-app login API without shipping a separate
        // helper bundle, so hand the user off to System Preferences instead.
        guard #available(macOS 13.0, *) else {
            let alert = NSAlert()
            alert.messageText = "Add them under Login Items"
            alert.informativeText = """
                On macOS 12 and earlier this is set in System Preferences → \
                Users & Groups → Login Items.
                """
            alert.addButton(withTitle: "Open Login Items")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(
                    URL(fileURLWithPath: "/System/Library/PreferencePanes/Accounts.prefPane"))
            }
            return
        }
        do {
            if loginEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change the login setting."
            alert.informativeText = "\(error.localizedDescription)\n\n"
                + "This usually needs the app to live in /Applications and be signed."
            alert.runModal()
        }
        refreshMenu()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = Product.current.name
        alert.informativeText = """
            \(Product.current.tagline)

            They walk about, throw punches, and square up when two of them end \
            up near each other. No internet, no analytics, nothing to sell you \
            — they have their own volume, separate from the system's, and you \
            can mute or quit them from this menu any time.

            \(Product.current.credit)
            """
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func quit() {
        for buddy in cast.onScreen { buddy.brain.vanish() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { NSApp.terminate(nil) }
    }
}
