import AppKit
import SwiftUI

@MainActor
final class PokerAppDelegate: NSObject, NSApplicationDelegate {
    static let shared = PokerAppDelegate()
    private var window: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let content = ContentView()
        NSApp.applicationIconImage = makePokerIcon(size: 512)

        let window = NSWindow(
            contentRect: NSRect(x: 160, y: 120, width: 940, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "HoldemPOC"
        window.contentView = NSHostingView(rootView: content)
        window.minSize = NSSize(width: 760, height: 560)
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            window.setFrame(frame, display: true)
        } else {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        self.window = window

        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makePokerIcon(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        NSColor.clear.setFill()
        rect.fill()

        let inset = size * 0.07
        let tileRect = rect.insetBy(dx: inset, dy: inset)
        let corner = size * 0.22
        let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: corner, yRadius: corner)
        tilePath.addClip()

        let tileGradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.02, green: 0.13, blue: 0.10, alpha: 1),
            NSColor(calibratedRed: 0.03, green: 0.27, blue: 0.19, alpha: 1)
        ])
        tileGradient?.draw(in: tileRect, angle: -35)
        tilePath.setClip()

        NSColor(calibratedWhite: 1.0, alpha: 0.20).setStroke()
        tilePath.lineWidth = max(2, size * 0.016)
        tilePath.stroke()

        let chipRect = NSRect(
            x: tileRect.minX + tileRect.width * 0.11,
            y: tileRect.minY + tileRect.height * 0.11,
            width: tileRect.width * 0.78,
            height: tileRect.height * 0.78
        )
        let chip = NSBezierPath(ovalIn: chipRect)
        NSColor(calibratedRed: 0.08, green: 0.66, blue: 0.38, alpha: 1).setFill()
        chip.fill()

        NSColor(calibratedWhite: 1.0, alpha: 0.85).setStroke()
        chip.lineWidth = size * 0.032
        chip.stroke()

        let innerRect = chipRect.insetBy(dx: size * 0.14, dy: size * 0.14)
        let inner = NSBezierPath(ovalIn: innerRect)
        NSColor(calibratedRed: 0.03, green: 0.24, blue: 0.17, alpha: 1).setFill()
        inner.fill()

        drawCard(
            in: NSRect(
                x: tileRect.minX + tileRect.width * 0.22,
                y: tileRect.minY + tileRect.height * 0.28,
                width: tileRect.width * 0.25,
                height: tileRect.height * 0.36
            ),
            rank: "A",
            suit: "♠"
        )
        drawCard(
            in: NSRect(
                x: tileRect.minX + tileRect.width * 0.43,
                y: tileRect.minY + tileRect.height * 0.36,
                width: tileRect.width * 0.25,
                height: tileRect.height * 0.36
            ),
            rank: "K",
            suit: "♥"
        )

        image.unlockFocus()
        return image
    }

    private func drawCard(in rect: NSRect, rank: String, suit: String) {
        let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.10, yRadius: rect.width * 0.10)
        NSColor.white.setFill()
        path.fill()
        NSColor(calibratedWhite: 0.12, alpha: 0.45).setStroke()
        path.lineWidth = max(1.0, rect.width * 0.03)
        path.stroke()

        let isRedSuit = suit == "♥" || suit == "♦"
        let color = isRedSuit ? NSColor.systemRed : NSColor.black
        let rankAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: rect.height * 0.23),
            .foregroundColor: color
        ]
        let suitAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: rect.height * 0.30),
            .foregroundColor: color
        ]

        let rankPoint = NSPoint(x: rect.minX + rect.width * 0.10, y: rect.maxY - rect.height * 0.30)
        let suitPoint = NSPoint(x: rect.midX - rect.width * 0.12, y: rect.midY - rect.height * 0.16)
        NSString(string: rank).draw(at: rankPoint, withAttributes: rankAttrs)
        NSString(string: suit).draw(at: suitPoint, withAttributes: suitAttrs)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct HoldemPOCMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = PokerAppDelegate.shared
        app.delegate = delegate
        app.run()
    }
}
