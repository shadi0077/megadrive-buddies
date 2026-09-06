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
    private var chattiness: Chattiness = .occasional
    private var liveliness: Liveliness = .occasional
    /// This app's own level, nothing to do with the system volume.
    private var volume: Float = 0.8
    private var language: Language = .english

    /// Shorthand for a menu string in the current language.
    private func t(_ key: String) -> String { UI.t(key, language) }

    func applicationDidFinishLaunching(_ note: Notification) {
        size = BuddySize(rawValue: CGFloat(defaults.double(forKey: "size"))) ?? .medium
        liveliness = Liveliness(rawValue: defaults.object(forKey: "liveliness") as? Int ?? 1)
            ?? .occasional
        chattiness = Chattiness(rawValue: defaults.object(forKey: "chattiness") as? Int ?? 1)
            ?? .occasional
        volume = Float(defaults.object(forKey: "volume") as? Double ?? 0.8)
        // Default to Arabic only if the Mac is already Arabic and a voice for
        // it exists; otherwise English, which every character always has.
        let systemPrefersArabic = Locale.preferredLanguages.first?.hasPrefix("ar") ?? false
        language = Language(rawValue: defaults.string(forKey: "language") ?? "")
            ?? (systemPrefersArabic ? .arabic : .english)

        cast = Cast(language: language, scale: size.rawValue)
        guard !cast.buddies.isEmpty else {
            let alert = NSAlert()
            alert.messageText = t("Nobody could be found.")
            alert.informativeText = t("Missing resources")
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        // Fall back if the chosen language has no installed voice.
        if !cast.availableLanguages.contains(language) {
            language = cast.availableLanguages.first ?? .english
            cast.speak(language)
        }
        cast.chattiness = chattiness
        cast.liveliness = liveliness

        for buddy in cast.buddies {
            restoreVoice(for: buddy)
            buddy.window.onRightClick = { [weak self] event in
                self?.popUpMenu(with: event, for: buddy)
            }
        }

        buildStatusItem()

        // Who was out last time. First run gets Peedy alone — two strangers at
        // once is a lot.
        var wanted = defaults.array(forKey: "onStage") as? [String] ?? ["peedy"]
        wanted = wanted.filter { cast.buddy($0) != nil }
        // Either character is optional — whoever's sprites were imported.
        if wanted.isEmpty, let first = cast.buddies.first?.id { wanted = [first] }
        cast.showAll(wanted) { [weak self] id in
            self?.defaults.string(forKey: "origin.\(id)").map(NSPointFromString)
                .flatMap { self?.onAScreen($0) }
        }

        // Debugging hook: PEEDY_TURN=song|joke|fact|riddle|twister|banter runs
        // that on launch, rather than waiting for the idle rotation.
        if let raw = ProcessInfo.processInfo.environment["PEEDY_LANG"],
           let forced = Language(rawValue: raw), forced != language {
            language = forced
            cast.speak(forced)
            for buddy in cast.buddies { restoreVoice(for: buddy) }
        }

        if let name = ProcessInfo.processInfo.environment["PEEDY_TURN"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self else { return }
                if name == "banter" { self.cast.gatherAndBanter() }
                else if let turn = Brain.Turn.allCases.first(where: { "\($0)" == name }) {
                    self.cast.onScreen.first?.brain.perform(turn, userAsked: true)
                }
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

    /// Voice and pitch overrides are saved per character *and* per language.
    ///
    /// They used to be saved per character only, which meant a voice chosen
    /// while speaking English was reapplied over the Arabic pack — and an
    /// English synthesiser handed Arabic spells it out at ten times the length,
    /// unintelligibly. A saved voice that can't speak the current language is
    /// now ignored outright.
    private func restoreVoice(for buddy: Buddy) {
        let voice = buddy.brain.voice
        voice.isEnabled = defaults.object(forKey: "voice") as? Bool ?? true
        voice.volume = volume
        guard buddy.personality.speaks else { return }

        let suffix = "\(buddy.id).\(language.rawValue)"
        if let saved = defaults.string(forKey: "voiceIdentifier.\(suffix)"),
           Voice.installed(saved), Voice.canSpeak(saved, language) {
            voice.identifier = saved
        }
        if let raw = defaults.object(forKey: "voicePitch.\(suffix)") as? Double,
           let pitch = Voice.Pitch(rawValue: Float(raw)) {
            voice.pitch = pitch
        }
    }

    // MARK: - Menu

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = statusIcon()
        statusItem.button?.toolTip = "Desktop Buddies"
        // Without this the item has no stable identity between launches, so
        // macOS (and menu-bar managers like Bartender) can't remember where the
        // user put it or whether they chose to show it.
        statusItem.autosaveName = "PeedyStatusItem"
        statusItem.menu = makeMenu()
    }

    /// Whoever is out, in miniature.
    ///
    /// Each character names its own frame for this in its catalogue — frame
    /// 380 of Peedy is a flying pose and 1159 of Bonzi is mid-swing, because
    /// their front-facing frames flatten into unreadable blobs at menu-bar
    /// size while these keep a recognisable outline. Falls back through a
    /// silhouette to an SF Symbol so the item is never blank, which on a
    /// menu-bar-only app would mean no way in at all.
    private func statusIcon() -> NSImage? {
        for buddy in cast.buddies where buddy.isVisible {
            if let icon = buddy.store.menuBarIcon(frame: buddy.store.heroFrame,
                                                  height: 18) {
                return icon
            }
        }
        if let first = cast.buddies.first,
           let icon = first.store.menuBarIcon(frame: first.store.heroFrame, height: 18) {
            return icon
        }
        for name in ["bird.fill", "bird"] {
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

        let silent = Product.current.isSilent
        menu.addItem(item(t(silent ? "Say Something" : "Say Hello"), #selector(sayHello)))
        menu.addItem(item(t("Tell a Joke"), #selector(tellJoke)))
        menu.addItem(item(t("Tell Me Something"), #selector(tellFact)))
        if !silent {
            menu.addItem(item(t("Sing a Song"), #selector(singSong)))
        }

        if present.count > 1 {
            menu.addItem(item(t(silent ? "Let Them Talk" : "Let Them Chat"),
                              #selector(haveThemChat)))
            if silent {
                menu.addItem(item(t("Let Them Fight"), #selector(haveThemFight)))
            }
        }

        if silent {
            menu.addItem(item(t("Do a Trick"), #selector(doTrick)))
        } else {
            let more = NSMenuItem(title: t("More"), action: nil, keyEquivalent: "")
            let moreMenu = NSMenu()
            moreMenu.addItem(item(t("Do a Trick"), #selector(doTrick)))
            moreMenu.addItem(item(t("Ask Me a Riddle"), #selector(tellRiddle)))
            moreMenu.addItem(item(t("Tongue Twister"), #selector(tellTwister)))
            more.submenu = moreMenu
            menu.addItem(more)
        }
        menu.addItem(.separator())

        // Who's out.
        let who = NSMenuItem(title: t("Who's Here"), action: nil, keyEquivalent: "")
        let whoMenu = NSMenu()
        for buddy in cast.buddies {
            let mi = item(buddy.brain.displayName, #selector(toggleCharacter(_:)))
            mi.representedObject = buddy.id
            mi.state = buddy.isVisible ? .on : .off
            whoMenu.addItem(mi)
        }
        who.submenu = whoMenu
        menu.addItem(who)

        // Per-character settings, so their voices stay distinct.
        for buddy in cast.buddies where buddy.isVisible {
            menu.addItem(characterMenu(for: buddy))
        }
        menu.addItem(.separator())

        // Language, when there's more than one to choose from.
        let usable = cast.availableLanguages
        if usable.count > 1 {
            let langItem = NSMenuItem(title: t("Language"), action: nil, keyEquivalent: "")
            let langMenu = NSMenu()
            for l in usable {
                let mi = item(l.title, #selector(setLanguage(_:)))
                mi.representedObject = l.rawValue
                mi.state = l == language ? .on : .off
                langMenu.addItem(mi)
            }
            langItem.submenu = langMenu
            menu.addItem(langItem)
        }

        let pace = NSMenuItem(title: t("Liveliness"), action: nil, keyEquivalent: "")
        let paceMenu = NSMenu()
        for level in Liveliness.allCases {
            let mi = item(t(level.title), #selector(setLiveliness(_:)))
            mi.representedObject = level.rawValue
            mi.state = level == liveliness ? .on : .off
            paceMenu.addItem(mi)
        }
        pace.submenu = paceMenu
        menu.addItem(pace)

        let chat = NSMenuItem(title: t("Chattiness"), action: nil, keyEquivalent: "")
        let chatMenu = NSMenu()
        for level in Chattiness.allCases {
            let mi = item(t(level.title), #selector(setChattiness(_:)))
            mi.representedObject = level.rawValue
            mi.state = level == chattiness ? .on : .off
            chatMenu.addItem(mi)
        }
        chat.submenu = chatMenu
        menu.addItem(chat)

        let sizeItem = NSMenuItem(title: t("Size"), action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for s in BuddySize.allCases {
            let mi = item(t(s.title), #selector(setSize(_:)))
            mi.representedObject = s.rawValue
            mi.state = s == size ? .on : .off
            sizeMenu.addItem(mi)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        let voiceOn = cast.buddies.first?.brain.voice.isEnabled ?? true
        menu.addItem(item(t(voiceOn ? "Mute Voices" : "Unmute Voices"),
                          #selector(toggleVoice)))

        // Their own level, not the system's.
        let volumeItem = NSMenuItem()
        volumeItem.view = VolumeSliderView(value: volume) { [weak self] level in
            self?.setVolume(level)
        }
        volumeItem.isEnabled = voiceOn
        menu.addItem(volumeItem)

        let login = item(t("Open at Login"), #selector(toggleLoginItem))
        login.state = loginEnabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item(t("About"), #selector(showAbout)))
        menu.addItem(item(t("Quit"), #selector(quit), key: "q"))
        return menu
    }

    private func characterMenu(for buddy: Buddy) -> NSMenuItem {
        let root = NSMenuItem(title: buddy.brain.displayName, action: nil, keyEquivalent: "")
        let sub = NSMenu()

        let come = item(t("Come Here"), #selector(comeHere(_:)))
        come.representedObject = buddy.id
        sub.addItem(come)

        let away = item(t("Send Away"), #selector(sendAway(_:)))
        away.representedObject = buddy.id
        sub.addItem(away)
        sub.addItem(.separator())

        let voices = buddy.personality.speaks ? Voice.options(for: language) : []
        if !voices.isEmpty {
            let voiceItem = NSMenuItem(title: t("Voice"), action: nil, keyEquivalent: "")
            let voiceMenu = NSMenu()
            for option in voices {
                let title = option.note.map { "\(option.title) — \($0)" } ?? option.title
                let mi = item(title, #selector(setVoice(_:)))
                mi.representedObject = [buddy.id, option.identifier]
                mi.state = option.identifier == buddy.brain.voice.identifier ? .on : .off
                voiceMenu.addItem(mi)
            }
            voiceItem.submenu = voiceMenu
            sub.addItem(voiceItem)

            let pitchItem = NSMenuItem(title: t("Pitch"), action: nil, keyEquivalent: "")
            let pitchMenu = NSMenu()
            for p in Voice.Pitch.allCases {
                let mi = item(t(p.title), #selector(setPitch(_:)))
                mi.representedObject = [buddy.id, "\(p.rawValue)"]
                mi.state = p == buddy.brain.voice.pitch ? .on : .off
                pitchMenu.addItem(mi)
            }
            pitchItem.submenu = pitchMenu
            sub.addItem(pitchItem)
        }

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
    private func speaker() -> Brain? {
        let free = cast.onScreen.filter { $0.brain.isAvailable }
        return (free.randomElement() ?? cast.onScreen.randomElement())?.brain
    }

    @objc private func sayHello() {
        for buddy in cast.onScreen where buddy.brain.isAvailable {
            buddy.brain.greet()
        }
    }

    @objc private func tellJoke() { speaker()?.perform(.joke, userAsked: true) }
    @objc private func tellFact() { speaker()?.perform(.fact, userAsked: true) }
    @objc private func tellRiddle() { speaker()?.perform(.riddle, userAsked: true) }
    @objc private func tellTwister() { speaker()?.perform(.twister, userAsked: true) }
    @objc private func singSong() { speaker()?.perform(.song, userAsked: true) }
    @objc private func doTrick() { speaker()?.doATrick() }
    @objc private func haveThemChat() {
        if Product.current.isSilent { cast.startGameBanter() } else { cast.gatherAndBanter() }
    }
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

    @objc private func setLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let chosen = Language(rawValue: raw), chosen != language else { return }
        language = chosen
        cast.speak(chosen)
        for buddy in cast.buddies { restoreVoice(for: buddy) }
        defaults.set(raw, forKey: "language")
        refreshMenu()
        // Say something immediately, so the change is audible rather than
        // just visible in a menu.
        cast.onScreen.randomElement()?.brain.greet()
    }

    @objc private func setLiveliness(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? Int,
              let level = Liveliness(rawValue: raw) else { return }
        liveliness = level
        cast.liveliness = level
        defaults.set(raw, forKey: "liveliness")
        refreshMenu()
    }

    @objc private func setChattiness(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? Int,
              let level = Chattiness(rawValue: raw) else { return }
        chattiness = level
        cast.chattiness = level
        defaults.set(raw, forKey: "chattiness")
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
            buddy.brain.voice.volume = volume
        }
        defaults.set(Double(volume), forKey: "volume")
        // Deliberately not rebuilding the menu: that would tear the slider out
        // from under the pointer mid-drag.
    }

    @objc private func toggleVoice() {
        let on = !(cast.buddies.first?.brain.voice.isEnabled ?? true)
        for buddy in cast.buddies {
            buddy.brain.voice.isEnabled = on
            buddy.brain.voice.volume = volume
            if !on { buddy.brain.voice.stop() }
        }
        defaults.set(on, forKey: "voice")
        refreshMenu()
    }

    @objc private func setVoice(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? [String], pair.count == 2,
              let buddy = cast.buddy(pair[0]) else { return }
        buddy.brain.voice.identifier = pair[1]
        defaults.set(pair[1], forKey: "voiceIdentifier.\(buddy.id).\(language.rawValue)")
        refreshMenu()
        buddy.brain.say(language == .arabic
                        ? "\(t("voice preview")) \(buddy.brain.displayName)."
                        : "Hello. My name is \(buddy.brain.displayName).")
    }

    @objc private func setPitch(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? [String], pair.count == 2,
              let buddy = cast.buddy(pair[0]),
              let raw = Float(pair[1]), let pitch = Voice.Pitch(rawValue: raw) else { return }
        buddy.brain.voice.pitch = pitch
        defaults.set(Double(raw), forKey: "voicePitch.\(buddy.id).\(language.rawValue)")
        refreshMenu()
        buddy.brain.say(t("pitch preview"))
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
            alert.messageText = t("Add them under Login Items")
            alert.informativeText = language == .arabic ? t("Login items body") : """
                On macOS 12 and earlier this is set in System Preferences → \
                Users & Groups → Login Items.
                """
            alert.addButton(withTitle: t("Open Login Items"))
            alert.addButton(withTitle: t("Cancel"))
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
            alert.messageText = t("Couldn't change the login setting.")
            alert.informativeText = "\(error.localizedDescription)\n\n"
                + (language == .arabic ? t("Login error hint")
                   : "This usually needs the app to live in /Applications and be signed.")
            alert.runModal()
        }
        refreshMenu()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = Product.current.name
        alert.informativeText = language == .arabic ? t("About body") : """
            Peedy is a parrot. Bonzi is a gorilla. They walk around, do bits, \
            and occasionally argue. Have one, or both.

            Neither connects to the internet, collects anything, changes your \
            browser, or has opinions to sell you. They have their own volume, \
            separate from the system's — mute or quit them from this menu any \
            time.

            Sprites from the Microsoft Agent character set.
            """
        alert.addButton(withTitle: t("OK"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func quit() {
        for buddy in cast.onScreen { buddy.brain.vanish() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { NSApp.terminate(nil) }
    }
}
