import AppKit

// all rects use global top-left coords, same as AX and CGWindowList
struct Display {
    let frame: CGRect
    let visible: CGRect // minus menu bar and Dock

    // sitting under the Dock is fine, a title bar under the menu bar isn't
    var usable: CGRect {
        CGRect(x: frame.minX, y: visible.minY, width: frame.width, height: frame.maxY - visible.minY)
    }
}

enum Displays {
    static func current() -> [Display] {
        let screens = NSScreen.screens
        guard let top = screens.first?.frame.maxY else { return [] }
        func flip(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: top - r.maxY, width: r.width, height: r.height) }
        return screens.map { Display(frame: flip($0.frame), visible: flip($0.visibleFrame)) }
    }

    // same monitors in the same arrangement give the same key
    static func key() -> String {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var n: UInt32 = 0
        guard CGGetActiveDisplayList(16, &ids, &n) == .success else { return "" }
        return ids.prefix(Int(n)).map { id in
            let uuid = CGDisplayCreateUUIDFromDisplayID(id).map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String } ?? "\(id)"
            let b = CGDisplayBounds(id)
            return "\(uuid) \(Int(b.minX)),\(Int(b.minY)) \(Int(b.width))x\(Int(b.height))"
        }.sorted().joined(separator: " | ")
    }
}

private let slack: CGFloat = 4

// part of the window is off every screen, or its title bar is under a menu bar
func isLost(_ f: CGRect, on displays: [Display]) -> Bool {
    guard f.width > 0, f.height > 0 else { return false }
    let seen = displays.reduce(0) { $0 + area(f.intersection($1.usable.insetBy(dx: -slack, dy: -slack))) }
    return seen < f.width * f.height - 1
}

// shrink to fit and slide fully onto the screen it mostly sits on
func fit(_ f: CGRect, on displays: [Display]) -> CGRect {
    let d = home(for: f, in: displays)
    let v = d.visible
    let w = min(f.width, v.width)
    let h = min(f.height, v.height)
    var x = f.minX
    var y = f.minY
    if !f.intersects(d.frame) {
        x = v.midX - w / 2
        y = v.midY - h / 2
    }
    x = max(min(x, v.maxX - w), v.minX)
    y = max(min(y, v.maxY - h), v.minY)
    return CGRect(x: x.rounded(), y: y.rounded(), width: w.rounded(.down), height: h.rounded(.down))
}

func home(for f: CGRect, in displays: [Display]) -> Display {
    let best = displays.max { area(f.intersection($0.frame)) < area(f.intersection($1.frame)) }!
    if area(f.intersection(best.frame)) > 0 { return best }
    let c = CGPoint(x: f.midX, y: f.midY)
    return displays.min { dist(c, $0.frame) < dist(c, $1.frame) }!
}

func same(_ a: CGRect, _ b: CGRect) -> Bool {
    abs(a.minX - b.minX) < 1 && abs(a.minY - b.minY) < 1 && abs(a.width - b.width) < 1 && abs(a.height - b.height) < 1
}

private func area(_ r: CGRect) -> CGFloat {
    r.isNull ? 0 : r.width * r.height
}

private func dist(_ p: CGPoint, _ r: CGRect) -> CGFloat {
    hypot(max(r.minX - p.x, 0, p.x - r.maxX), max(r.minY - p.y, 0, p.y - r.maxY))
}
