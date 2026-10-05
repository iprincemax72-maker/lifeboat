import AppKit
import ApplicationServices

// private, but it's been stable for years and Rectangle, AltTab and friends all lean on it
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ el: AXUIElement, _ id: inout CGWindowID) -> AXError

struct Window {
    let el: AXUIElement
    let app: AXUIElement
    let id: CGWindowID
    let frame: CGRect
}

enum Windows {
    // normal windows on the current space(s), which is all AX can reach
    static func visible() -> [Window] {
        let shown = Set(onAllSpaces().filter { $0.onScreen }.map { $0.id })
        var out: [Window] = []
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && !app.isHidden && app.processIdentifier != getpid() {
            let ax = AXUIElementCreateApplication(app.processIdentifier)
            guard let wins = get(ax, kAXWindowsAttribute) as? [AXUIElement] else { continue }
            for w in wins where isNormal(w) {
                guard let f = frame(of: w) else { continue }
                var id: CGWindowID = 0
                _ = _AXUIElementGetWindow(w, &id)
                // skip ordered-out and invisible helper windows
                if id != 0 && !shown.contains(id) { continue }
                out.append(Window(el: w, app: ax, id: id, frame: f))
            }
        }
        return out
    }

    // every window on every space, straight from the window server. read only
    static func onAllSpaces() -> [(id: CGWindowID, frame: CGRect, onScreen: Bool)] {
        guard let list = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { info in
            guard info[kCGWindowLayer as String] as? Int == 0,
                  let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return nil }
            let onScreen = info[kCGWindowIsOnscreen as String] as? Bool == true
            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
            return (id, frame, onScreen && alpha > 0)
        }
    }

    static func move(_ w: Window, to r: CGRect, on displays: [Display]) {
        // with AXEnhancedUserInterface on, some apps animate moves and drop them
        let enhanced = get(w.app, "AXEnhancedUserInterface") as? Bool == true
        if enhanced { AXUIElementSetAttributeValue(w.app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse) }
        defer { if enhanced { AXUIElementSetAttributeValue(w.app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue) } }

        set(w.el, kAXSizeAttribute, r.size)
        set(w.el, kAXPositionAttribute, r.origin)
        set(w.el, kAXSizeAttribute, r.size)

        // some apps won't shrink past a minimum size, so at least get the title bar on screen
        if let now = frame(of: w.el), isLost(now, on: displays) {
            set(w.el, kAXPositionAttribute, fit(now, on: displays).origin)
        }
    }

    private static func isNormal(_ w: AXUIElement) -> Bool {
        let sub = get(w, kAXSubroleAttribute) as? String
        guard sub == kAXStandardWindowSubrole || sub == kAXDialogSubrole else { return false }
        if get(w, kAXMinimizedAttribute) as? Bool == true { return false }
        if get(w, "AXFullScreen") as? Bool == true { return false }
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(w, kAXPositionAttribute as CFString, &settable) == .success && settable.boolValue
    }

    private static func frame(of w: AXUIElement) -> CGRect? {
        guard let p = get(w, kAXPositionAttribute), let s = get(w, kAXSizeAttribute),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &origin), AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func get(_ el: AXUIElement, _ attr: String) -> CFTypeRef? {
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success ? v : nil
    }

    private static func set(_ el: AXUIElement, _ attr: String, _ p: CGPoint) {
        var p = p
        if let v = AXValueCreate(.cgPoint, &p) { AXUIElementSetAttributeValue(el, attr as CFString, v) }
    }

    private static func set(_ el: AXUIElement, _ attr: String, _ s: CGSize) {
        var s = s
        if let v = AXValueCreate(.cgSize, &s) { AXUIElementSetAttributeValue(el, attr as CFString, v) }
    }
}
