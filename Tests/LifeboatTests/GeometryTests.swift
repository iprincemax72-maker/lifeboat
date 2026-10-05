import CoreGraphics
import Testing
@testable import Lifeboat

// 1470x956 laptop with a notch-height menu bar and the Dock at the bottom
let laptop = Display(frame: CGRect(x: 0, y: 0, width: 1470, height: 956),
                     visible: CGRect(x: 0, y: 37, width: 1470, height: 849))
// 1920x1080 monitor to the left of it
let monitor = Display(frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
                      visible: CGRect(x: -1920, y: 25, width: 1920, height: 1055))

@Test func windowThatFitsIsLeftAlone() {
    #expect(!isLost(CGRect(x: 100, y: 37, width: 800, height: 600), on: [laptop]))
}

@Test func monitorSizedWindowShrinksToTheLaptop() {
    let f = CGRect(x: 0, y: 37, width: 1920, height: 1080)
    #expect(isLost(f, on: [laptop]))
    #expect(fit(f, on: [laptop]) == laptop.visible)
}

@Test func windowHangingOffTheEdgeSlidesBack() {
    let f = CGRect(x: 1200, y: 200, width: 800, height: 500)
    #expect(isLost(f, on: [laptop]))
    #expect(fit(f, on: [laptop]) == CGRect(x: 670, y: 200, width: 800, height: 500))
}

@Test func windowNowhereNearGetsCentered() {
    let f = CGRect(x: 4000, y: 3000, width: 600, height: 400)
    #expect(isLost(f, on: [laptop]))
    #expect(fit(f, on: [laptop]) == CGRect(x: 435, y: 262, width: 600, height: 400))
}

@Test func titleBarUnderTheMenuBarCounts() {
    let f = CGRect(x: 100, y: 10, width: 800, height: 600)
    #expect(isLost(f, on: [laptop]))
    #expect(fit(f, on: [laptop]).minY == 37)
}

@Test func overlappingTheDockIsFine() {
    #expect(!isLost(CGRect(x: 100, y: 300, width: 800, height: 640), on: [laptop]))
}

@Test func aFewPointsOverIsFine() {
    #expect(!isLost(CGRect(x: 673, y: 100, width: 800, height: 500), on: [laptop]))
}

@Test func spanningTwoScreensIsFine() {
    #expect(!isLost(CGRect(x: -400, y: 100, width: 800, height: 600), on: [monitor, laptop]))
}

@Test func lostWindowGoesToTheScreenItMostlyOverlaps() {
    let f = CGRect(x: -300, y: 800, width: 1000, height: 300)
    #expect(home(for: f, in: [monitor, laptop]).frame == laptop.frame)
}

@Test func tooTallWindowStaysOnItsOwnScreen() {
    let f = CGRect(x: -1800, y: 500, width: 1000, height: 800)
    #expect(isLost(f, on: [monitor, laptop]))
    #expect(fit(f, on: [monitor, laptop]) == CGRect(x: -1800, y: 280, width: 1000, height: 800))
}
