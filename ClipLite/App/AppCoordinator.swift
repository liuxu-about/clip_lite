import AppKit
import Foundation

@MainActor
final class AppCoordinator {
    private let viewModel = ClipboardPanelViewModel()
    private let permissionService = AccessibilityPermissionService()
    private lazy var inputAnchorLocator = InputAnchorLocator(permissionService: permissionService)
    private let settingsManager = SettingsManager()
    private let startupManager = StartupManager()

    private lazy var pasteExecutor = PasteExecutor(permissionService: permissionService)
    private lazy var panelController = ClipboardPanelController(
        viewModel: viewModel,
        onConfirmSelection: { [weak self] in self?.handleConfirmSelection() }
    )
    private lazy var keyRouter = PanelKeyEventRouter(
        onMoveUp: { [weak self] in self?.handleMoveSelectionUp() },
        onMoveDown: { [weak self] in self?.handleMoveSelectionDown() },
        onConfirm: { [weak self] in self?.handleConfirmSelection() },
        onSelectByNumber: { [weak self] number in self?.handleQuickSelect(number) ?? false },
        onSearchTrigger: { [weak self] in self?.handleSearchTrigger() ?? false },
        onTogglePreview: { [weak self] in self?.handlePreviewToggle() ?? false },
        onEscape: { [weak self] in self?.handleEscape() }
    )

    private var historyStore: HistoryStore?
    private var cleanupService: CleanupService?
    private var clipboardMonitor: ClipboardMonitor?
    private var settingsWindowController: SettingsWindowController?
    private var clipInsertedObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?
    private var hotkeyManager: HotkeyManager?
    private var statusBarController: StatusBarController?
    private var activeHotkeyPreset: HotkeyPreset?

    func start() {
        Logger.info("ClipLite launching")

        settingsWindowController = SettingsWindowController(
            settingsManager: settingsManager,
            startupManager: startupManager
        )

        configureStorageAndMonitor()
        configureSettingsObservation()
        applyTheme(settingsManager.settings.themeMode)

        panelController.onDidHide = { [weak self] in
            self?.keyRouter.stop()
        }

        statusBarController = StatusBarController(delegate: self)

        pasteExecutor.onDidWritePasteboard = { [weak self] changeCount in
            self?.clipboardMonitor?.markIgnoredChangeCount(changeCount)
        }

        let hotkeyManager = HotkeyManager()
        hotkeyManager.onHotkeyPressed = { [weak self] in
            Task { @MainActor [weak self] in
                self?.togglePanelVisibility()
            }
        }
        self.hotkeyManager = hotkeyManager
        applyHotkey(settingsManager.settings.hotkeyPreset)

        Logger.info("ClipLite started")
    }

    func stop() {
        clipboardMonitor?.stop()

        if let clipInsertedObserver {
            NotificationCenter.default.removeObserver(clipInsertedObserver)
            self.clipInsertedObserver = nil
        }

        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
            self.settingsObserver = nil
        }

        hotkeyManager?.unregister()
        keyRouter.stop()
        Logger.info("ClipLite stopped")
    }

    private func configureStorageAndMonitor() {
        do {
            let store = try HistoryStore()
            historyStore = store
            cleanupService = CleanupService(historyStore: store)
            refreshItemsFromStore()

            let monitor = ClipboardMonitor(
                parser: ClipboardParser(),
                historyStore: store,
                pollingInterval: 0.12
            )
            monitor.settingsProvider = { [weak self] in
                self?.settingsManager.settings ?? .default
            }
            monitor.start()
            clipboardMonitor = monitor

            clipInsertedObserver = NotificationCenter.default.addObserver(
                forName: .clipLiteDidInsertClip,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.refreshItemsFromStore()
                    self.cleanupService?.scheduleThrottled(
                        settings: self.settingsManager.settings,
                        reason: "new clip"
                    )
                }
            }

            cleanupService?.runNow(settings: settingsManager.settings, reason: "startup")
        } catch {
            Logger.error("Failed to initialize storage: \(error)")
            loadMockDataFallback()
        }
    }

    private func configureSettingsObservation() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .clipLiteSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let selectedPreset = self.settingsManager.settings.hotkeyPreset
                if selectedPreset != self.activeHotkeyPreset {
                    self.applyHotkey(selectedPreset)
                }
                self.applyTheme(self.settingsManager.settings.themeMode)
                self.refreshItemsFromStore()
                self.cleanupService?.scheduleThrottled(
                    settings: self.settingsManager.settings,
                    reason: "settings changed",
                    delay: 0.1
                )
            }
        }
    }

    private func applyTheme(_ theme: ThemeMode) {
        switch theme {
        case .followSystem:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func applyHotkey(_ preset: HotkeyPreset) {
        guard let hotkeyManager else {
            return
        }

        if hotkeyManager.register(hotkey: preset) {
            activeHotkeyPreset = preset
            return
        }

        let fallbackPreset = activeHotkeyPreset ?? .commandShiftV
        Logger.warning("Hotkey registration failed for \(preset.displayName). Reverting to \(fallbackPreset.displayName)")
        NSSound.beep()

        if preset != fallbackPreset {
            if hotkeyManager.register(hotkey: fallbackPreset) {
                activeHotkeyPreset = fallbackPreset
            } else {
                Logger.error("Fallback hotkey registration also failed: \(fallbackPreset.displayName)")
            }
        } else {
            Logger.error("No fallback hotkey available after registration failure")
        }

        if let activeHotkeyPreset, settingsManager.settings.hotkeyPreset != activeHotkeyPreset {
            settingsManager.update { $0.hotkeyPreset = activeHotkeyPreset }
        }
    }

    private func refreshItemsFromStore() {
        guard let historyStore else {
            return
        }

        let limit = HistoryFetchPolicy.fetchLimit(maxItemCount: settingsManager.settings.maxItemCount)
        let items = historyStore.fetchRecent(limit: limit)
        viewModel.setItems(items)
    }

    private func loadMockDataFallback() {
        let sampleTexts = [
            "Hello from ClipLite",
            "let value = 42",
            "https://example.com"
        ]

        let samples = sampleTexts.map {
            ClipItem(
                type: .text,
                hashValue: Hashing.sha256($0),
                textContent: $0,
                textPreview: $0
            )
        }

        viewModel.setItems(samples)
    }

    private func handleConfirmSelection() {
        guard let selected = viewModel.selectedItem else {
            NSSound.beep()
            return
        }

        hidePanel()

        let result = pasteExecutor.paste(item: selected, promptForPermissionIfNeeded: true)
        switch result {
        case .autoPasted:
            Logger.info("Auto paste succeeded")
        case .copiedOnly(let reason):
            Logger.warning("Copied only: \(reason)")
            NSSound.beep()
        case .failed(let reason):
            Logger.error("Paste failed: \(reason)")
            NSSound.beep()
        }
    }

    private func handleQuickSelect(_ number: Int) -> Bool {
        guard !viewModel.isSearchMode else {
            return false
        }

        let targetIndex = number - 1
        guard viewModel.select(index: targetIndex) else {
            NSSound.beep()
            return true
        }
        handleConfirmSelection()
        return true
    }

    private func handleSearchTrigger() -> Bool {
        viewModel.activateSearchFromShortcut()
        return true
    }

    private func handleMoveSelectionUp() {
        let previousSelectedID = viewModel.selectedItem?.id
        viewModel.moveSelectionUp()
        if viewModel.selectedItem?.id != previousSelectedID {
            viewModel.notifyKeyboardNavigation()
        }
    }

    private func handleMoveSelectionDown() {
        let previousSelectedID = viewModel.selectedItem?.id
        viewModel.moveSelectionDown()
        if viewModel.selectedItem?.id != previousSelectedID {
            viewModel.notifyKeyboardNavigation()
        }
    }

    private func handleEscape() {
        if viewModel.previewedItemID != nil {
            viewModel.clearPreview()
            return
        }

        if viewModel.isSearchMode {
            viewModel.exitSearchMode()
            return
        }
        hidePanel()
    }

    private func handlePreviewToggle() -> Bool {
        if viewModel.isSearchFieldFocused {
            return false
        }

        if viewModel.togglePreviewForSelectedItem() {
            return true
        }

        NSSound.beep()
        return true
    }

    private func showPanel() {
        refreshItemsFromStore()
        viewModel.exitSearchMode()
        viewModel.clearPreview()
        viewModel.selectFirstItem()
        let anchorRect = inputAnchorLocator.focusedElementFrameInScreen()
        if let anchorRect {
            Logger.debug("Panel anchor resolved: x=\(Int(anchorRect.origin.x)) y=\(Int(anchorRect.origin.y)) w=\(Int(anchorRect.width)) h=\(Int(anchorRect.height))")
        } else {
            Logger.debug("Panel anchor unavailable; falling back to top-centered frame")
        }
        panelController.show(anchorRect: anchorRect)
        keyRouter.start()
        Logger.debug("Clipboard panel shown")
    }

    private func hidePanel() {
        viewModel.clearPreview()
        panelController.hide()
        keyRouter.stop()
        Logger.debug("Clipboard panel hidden")
    }

    private func togglePanelVisibility() {
        if panelController.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }
}

extension AppCoordinator: StatusBarControllerDelegate {
    func statusBarDidRequestShowPanel() {
        togglePanelVisibility()
    }

    func statusBarDidRequestOpenSettings() {
        settingsWindowController?.showOrFocus()
    }

    func statusBarDidRequestQuit() {
        NSApplication.shared.terminate(nil)
    }
}
