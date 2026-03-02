import AppKit

@main
enum ClipLiteMain {
    @MainActor
    static func main() {
        let appDelegate = AppDelegate()
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = appDelegate
        app.run()
    }
}
