import AppKit
import os

private let log = Logger(subsystem: "app.dropnotch.Lifeboat", category: "rescue")

final class Rescuer: NSObject {
    var restoreOn: Bool {
        get { UserDefaults.standard.object(forKey: "restoreLayouts") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "restoreLayouts")
            if !newValue {
                layouts = [:]
                targets = [:]
            }
        }
    }

    // where windows sat in each display setup, keyed by Displays.key()
    private var layouts: [String: [CGWindowID: CGRect]] = [:]
    // where windows go back to after the last display change
    private var targets: [CGWindowID: CGRect] = [:]
    // windows from the last display change that haven't been on screen since (other spaces, hidden apps)
    private var pending = Set<CGWindowID>()
    private var settling = false
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1)

        CGDisplayRegisterReconfigurationCallback({ _, _, me in
            let me = Unmanaged<Rescuer>.fromOpaque(me!).takeUnretainedValue()
            me.performSelector(onMainThread: #selector(Rescuer.displaysChanged), with: nil, waitUntilDone: false)
        }, Unmanaged.passUnretained(self).toOpaque())

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(windowsAppeared), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(windowsAppeared), name: NSWorkspace.didUnhideApplicationNotification, object: nil)

        let timer = Timer(timeInterval: 2, target: self, selector: #selector(snapshot), userInfo: nil, repeats: true)
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        snapshot()
    }

    func rescue() {
        let n = pass(targets: [:])
        log.info("rescue moved \(n) windows")
    }

    @objc private func displaysChanged() {
        settling = true
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        later(#selector(settled), 1.5)
    }

    @objc private func settled() {
        targets = restoreOn ? layouts[Displays.key()] ?? [:] : [:]
        pending = Set(Windows.onAllSpaces().map { $0.id })
        let n = pass(targets: targets)
        log.info("displays changed, moved \(n) windows")
        // some apps shuffle their own windows again a beat later
        later(#selector(settledAgain), 2)
    }

    @objc private func settledAgain() {
        pass(targets: targets)
        settling = false
    }

    @objc private func windowsAppeared() {
        guard !pending.isEmpty, !settling else { return }
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(catchUp), object: nil)
        later(#selector(catchUp), 0.5)
    }

    @objc private func catchUp() {
        pass(targets: targets, only: pending)
    }

    @objc private func snapshot() {
        guard restoreOn, !settling else { return }
        let key = Displays.key()
        let wins = Windows.onAllSpaces()
        let alive = Set(wins.map { $0.id })
        pending.formIntersection(alive)
        layouts = layouts.mapValues { $0.filter { alive.contains($0.key) } }

        var layout = layouts[key] ?? [:]
        for w in wins where w.onScreen && !pending.contains(w.id) {
            layout[w.id] = w.frame
        }
        // displays changed mid-read, so these frames can't be trusted
        guard Displays.key() == key else { return }
        layouts[key] = layout
    }

    @discardableResult
    private func pass(targets: [CGWindowID: CGRect], only: Set<CGWindowID>? = nil) -> Int {
        let displays = Displays.current()
        guard !displays.isEmpty else { return 0 }
        var moved = 0
        for w in Windows.visible() {
            if let only, !only.contains(w.id) { continue }
            pending.remove(w.id)
            var want = targets[w.id] ?? w.frame
            if isLost(want, on: displays) { want = fit(want, on: displays) }
            guard !same(want, w.frame) else { continue }
            Windows.move(w, to: want, on: displays)
            moved += 1
        }
        return moved
    }

    private func later(_ action: Selector, _ delay: TimeInterval) {
        perform(action, with: nil, afterDelay: delay, inModes: [.common])
    }
}
