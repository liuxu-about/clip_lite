import AppKit
import Foundation

@MainActor
protocol StatusBarControllerDelegate: AnyObject {
    func statusBarDidRequestShowPanel()
    func statusBarDidRequestOpenSettings()
    func statusBarDidRequestQuit()
}

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private weak var delegate: StatusBarControllerDelegate?

    init(delegate: StatusBarControllerDelegate) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.delegate = delegate
        super.init()
        configureStatusItem()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = loadStatusBarIcon()
            button.imagePosition = .imageOnly
            button.toolTip = "ClipLite"
        }

        statusItem.menu = buildMenu()
    }

    private func loadStatusBarIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "StatusBarIconTemplate", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }

        return NSImage(systemSymbolName: "paperclip", accessibilityDescription: "ClipLite")
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Clipboard", action: #selector(handleOpenClipboard), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(handleOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit ClipLite", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc
    private func handleOpenClipboard() {
        delegate?.statusBarDidRequestShowPanel()
    }

    @objc
    private func handleOpenSettings() {
        delegate?.statusBarDidRequestOpenSettings()
    }

    @objc
    private func handleQuit() {
        delegate?.statusBarDidRequestQuit()
    }
}
