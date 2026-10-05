import AppKit
import Carbon
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let rescuer = Rescuer()
    private var hotkey: Hotkey?
    private var trustTimer: Timer?

    func applicationDidFinishLaunching(_ note: Notification) {
        if alreadyRunning() {
            NSApp.terminate(nil)
            return
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        hotkey = Hotkey(key: kVK_ANSI_R, mods: controlKey | optionKey | cmdKey) { [weak self] in
            self?.rescue()
        }

        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "launchedBefore") {
            defaults.set(true, forKey: "launchedBefore")
            // so it's already running the next time a monitor gets unplugged
            if Bundle.main.bundlePath.hasPrefix("/Applications/") {
                try? SMAppService.mainApp.register()
            }
        }

        if AXIsProcessTrusted() {
            rescuer.start()
        } else {
            AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            trustTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(checkTrust), userInfo: nil, repeats: true)
        }
        updateIcon()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if !AXIsProcessTrusted() {
            add(menu, "Allow Accessibility Access…", #selector(openAccessSettings))
            menu.addItem(withTitle: "Lifeboat needs it to move windows", action: nil, keyEquivalent: "").isEnabled = false
            menu.addItem(.separator())
        }

        add(menu, "Rescue Windows", #selector(rescue), key: "r").keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(.separator())
        add(menu, "Remember Layout per Display Setup", #selector(toggleRestore)).state = rescuer.restoreOn ? .on : .off
        add(menu, "Launch at Login", #selector(toggleLogin)).state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(.separator())
        add(menu, "About Lifeboat", #selector(about))
        add(menu, "Quit Lifeboat", #selector(NSApplication.terminate(_:)), key: "q", target: NSApp)
    }

    @objc private func rescue() {
        guard AXIsProcessTrusted() else {
            openAccessSettings()
            return
        }
        rescuer.rescue()
        // quick blink so you know it fired
        statusItem.button?.image = icon("lifepreserver.fill")
        perform(#selector(updateIcon), with: nil, afterDelay: 0.4)
    }

    @objc private func checkTrust() {
        guard AXIsProcessTrusted() else { return }
        trustTimer?.invalidate()
        trustTimer = nil
        rescuer.start()
        rescuer.rescue()
        updateIcon()
    }

    @objc private func updateIcon() {
        statusItem.button?.image = icon("lifepreserver")
        statusItem.button?.appearsDisabled = !AXIsProcessTrusted()
    }

    @objc private func toggleRestore() {
        rescuer.restoreOn.toggle()
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        if service.status == .enabled {
            try? service.unregister()
        } else {
            try? service.register()
            if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        }
    }

    @objc private func openAccessSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func about() {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .paragraphStyle: style]
        func link(_ text: String, _ url: String) -> NSAttributedString {
            NSAttributedString(string: text, attributes: attrs.merging([.link: URL(string: url)!]) { $1 })
        }

        let credits = NSMutableAttributedString(string: "Puts your windows back on screen when a monitor comes or goes.\n\n", attributes: attrs)
        credits.append(link("github.com/iprincemax72-maker/lifeboat", "https://github.com/iprincemax72-maker/lifeboat"))
        credits.append(NSAttributedString(string: "\nFrom the maker of ", attributes: attrs))
        credits.append(link("Drop Notch", "https://dropnotch.space"))

        if #available(macOS 14, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "", target: AnyObject? = nil) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = target ?? self
        return item
    }

    private func icon(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: "Lifeboat")
    }

    private func alreadyRunning() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: id).contains { $0.processIdentifier != getpid() }
    }
}
