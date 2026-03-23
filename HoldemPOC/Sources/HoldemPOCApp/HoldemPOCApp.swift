import AppKit
import ScreenCaptureKit
import SwiftUI

@MainActor
final class PokerAppDelegate: NSObject, NSApplicationDelegate {
    static let shared = PokerAppDelegate()
    private var window: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let env = ProcessInfo.processInfo.environment
        let debugScene = env["HOLDEM_LAYOUT_DEBUG_SCENE"].flatMap(LayoutDebugScene.init(rawValue:))
        let snapshotPath = env["HOLDEM_UI_SNAPSHOT_PATH"]
        let isDeterministicWindow = debugScene != nil || (snapshotPath?.isEmpty == false)
        let configuredWidth = CGFloat(Double(env["HOLDEM_UI_WINDOW_WIDTH"] ?? "") ?? 0)
        let configuredHeight = CGFloat(Double(env["HOLDEM_UI_WINDOW_HEIGHT"] ?? "") ?? 0)
        let windowWidth = configuredWidth > 0 ? configuredWidth : (isDeterministicWindow ? 1440 : 0)
        let windowHeight = configuredHeight > 0 ? configuredHeight : (isDeterministicWindow ? 900 : 0)
        let content: AnyView
        if let debugScene {
            content = AnyView(LayoutDebugHarnessView(scene: debugScene))
        } else {
            content = AnyView(ContentView())
        }
        NSApp.applicationIconImage = makePokerIcon(size: 512)

        let window = NSWindow(
            contentRect: NSRect(x: 160, y: 120, width: max(940, windowWidth), height: max(640, windowHeight)),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = debugScene == nil ? "HoldemPOC" : "HoldemPOC Debug"
        window.contentView = NSHostingView(rootView: content)
        window.minSize = NSSize(width: 760, height: 560)
        if windowWidth > 0, windowHeight > 0 {
            window.setContentSize(NSSize(width: windowWidth, height: windowHeight))
            window.center()
        } else if let screen = NSScreen.main {
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

        maybeCaptureSnapshot(of: window)
    }

    private func maybeCaptureSnapshot(of window: NSWindow) {
        let env = ProcessInfo.processInfo.environment
        guard let snapshotPath = env["HOLDEM_UI_SNAPSHOT_PATH"], !snapshotPath.isEmpty else {
            return
        }
        let delay = Double(env["HOLDEM_UI_SNAPSHOT_DELAY"] ?? "0.8") ?? 0.8
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            Task { @MainActor in
                await self?.writeSnapshotAndTerminate(of: window, to: snapshotPath)
            }
        }
    }

    private func writeSnapshotAndTerminate(of window: NSWindow, to path: String) async {
        guard await writeSnapshot(of: window, to: path) else {
            reportSnapshotFailure(path: path)
            exit(EXIT_FAILURE)
        }
        NSApp.terminate(nil)
    }

    private func writeSnapshot(of window: NSWindow, to path: String) async -> Bool {
        guard let contentView = window.contentView else { return false }
        window.displayIfNeeded()
        contentView.layoutSubtreeIfNeeded()

        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if let cgImage = await captureWindowImageWithScreenCaptureKit(window) {
            let rep = NSBitmapImageRep(cgImage: cgImage)
            if let data = rep.representation(using: .png, properties: [:]) {
                do {
                    try data.write(to: url)
                    return true
                } catch {
                    return false
                }
            }
        }
        return false
    }

    private func captureWindowImageWithScreenCaptureKit(_ window: NSWindow) async -> CGImage? {
        let targetWindowID = CGWindowID(window.windowNumber)
        do {
            for attempt in 0..<6 {
                let shareableContent = try await currentProcessShareableContent().value
                if let scWindow = shareableContent.windows.first(where: { $0.windowID == targetWindowID }) {
                    let filter = SCContentFilter(desktopIndependentWindow: scWindow)
                    let config = SCStreamConfiguration()
                    let scale = max(1.0, CGFloat(filter.pointPixelScale))
                    let contentRect = filter.contentRect
                    config.width = max(1, Int(round(contentRect.width * scale)))
                    config.height = max(1, Int(round(contentRect.height * scale)))
                    config.showsCursor = false
                    config.scalesToFit = false
                    config.ignoreShadowsSingleWindow = true
                    config.shouldBeOpaque = false
                    return try await captureImage(contentFilter: filter, configuration: config)
                }

                if attempt < 5 {
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    private func currentProcessShareableContent() async throws -> SendableBox<SCShareableContent> {
        try await withCheckedThrowingContinuation { continuation in
            let finish: @Sendable (SCShareableContent?, Error?) -> Void = { content, error in
                if let content {
                    continuation.resume(returning: SendableBox(value: content))
                } else {
                    continuation.resume(throwing: error ?? SnapshotCaptureError.shareableContentUnavailable)
                }
            }

            if #available(macOS 14.4, *) {
                SCShareableContent.getCurrentProcessShareableContent(completionHandler: finish)
            } else {
                SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true, completionHandler: finish)
            }
        }
    }

    private func captureImage(
        contentFilter: SCContentFilter,
        configuration: SCStreamConfiguration
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: contentFilter, configuration: configuration) { image, error in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: error ?? SnapshotCaptureError.imageCaptureFailed)
                }
            }
        }
    }

    private func reportSnapshotFailure(path: String) {
        let message = "ScreenCaptureKit snapshot capture failed for \(path)\n"
        if let data = message.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
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

private enum SnapshotCaptureError: Error {
    case shareableContentUnavailable
    case imageCaptureFailed
}

private struct SendableBox<Value>: @unchecked Sendable {
    let value: Value
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
