import AppKit
import Foundation

extension Notification.Name {
    static let clipLiteDidInsertClip = Notification.Name("clipLiteDidInsertClip")
}

final class ClipboardMonitor: NSObject {
    var settingsProvider: (() -> AppSettings)?

    private let clipboardSource: ClipboardChangeSource
    private let parsePayload: () -> ClipboardPayload?
    private let savePayload: @Sendable (ClipboardPayload, AppSettings) -> SaveClipResult
    private let pollingInterval: TimeInterval
    private let burstPollingInterval: TimeInterval
    private let burstPollIterations: Int
    private let processingQueue = DispatchQueue(label: "com.cliplite.clipboard.processing", qos: .utility)

    private var timer: Timer?
    private var burstPollWorkItem: DispatchWorkItem?
    private var lastChangeCount: Int
    private var ignoredChangeCounts = Set<Int>()
    private var pendingBurstPolls = 0
    private var isRunning = false

    convenience init(
        pasteboard: NSPasteboard = .general,
        parser: ClipboardParser,
        historyStore: HistoryStore,
        pollingInterval: TimeInterval = 0.12,
        burstPollingInterval: TimeInterval = 0.06,
        burstPollIterations: Int = 16
    ) {
        self.init(
            clipboardSource: pasteboard,
            parsePayload: { parser.parse(from: pasteboard) },
            savePayload: { payload, settings in
                switch payload {
                case .text(let text):
                    return historyStore.saveTextClip(text, settings: settings)
                case .image(let image):
                    return historyStore.saveImageClip(
                        data: image.data,
                        width: image.width,
                        height: image.height,
                        settings: settings
                    )
                }
            },
            pollingInterval: pollingInterval,
            burstPollingInterval: burstPollingInterval,
            burstPollIterations: burstPollIterations
        )
    }

    init(
        clipboardSource: ClipboardChangeSource,
        parsePayload: @escaping () -> ClipboardPayload?,
        savePayload: @escaping @Sendable (ClipboardPayload, AppSettings) -> SaveClipResult,
        pollingInterval: TimeInterval = 0.12,
        burstPollingInterval: TimeInterval = 0.06,
        burstPollIterations: Int = 16
    ) {
        self.clipboardSource = clipboardSource
        self.parsePayload = parsePayload
        self.savePayload = savePayload
        self.pollingInterval = max(0.05, pollingInterval)
        self.burstPollingInterval = max(0.02, min(burstPollingInterval, self.pollingInterval))
        self.burstPollIterations = max(1, burstPollIterations)
        self.lastChangeCount = clipboardSource.changeCount
    }

    func start() {
        stop()

        isRunning = true
        lastChangeCount = clipboardSource.changeCount
        timer = Timer.scheduledTimer(
            timeInterval: pollingInterval,
            target: self,
            selector: #selector(pollPasteboard),
            userInfo: nil,
            repeats: true
        )
        timer?.tolerance = min(0.01, pollingInterval * 0.2)

        Logger.info("Clipboard monitor started with interval: \(pollingInterval)s")
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        burstPollWorkItem?.cancel()
        burstPollWorkItem = nil
        pendingBurstPolls = 0
    }

    func markIgnoredChangeCount(_ changeCount: Int) {
        ignoredChangeCounts.insert(changeCount)
    }

    @objc
    private func pollPasteboard() {
        guard isRunning else {
            return
        }

        let currentChangeCount = clipboardSource.changeCount
        guard currentChangeCount != lastChangeCount else {
            return
        }

        let skippedChangeCount = max(0, currentChangeCount - lastChangeCount - 1)
        if skippedChangeCount > 0 {
            Logger.warning("Detected \(skippedChangeCount) clipboard updates between polls; enabling burst polling.")
        }

        lastChangeCount = currentChangeCount
        ignoredChangeCounts = ignoredChangeCounts.filter { $0 >= currentChangeCount }

        if ignoredChangeCounts.contains(currentChangeCount) {
            ignoredChangeCounts.remove(currentChangeCount)
            Logger.debug("Ignored self-written pasteboard changeCount=\(currentChangeCount)")
            scheduleBurstPolling()
            return
        }

        guard let payload = parsePayload() else {
            scheduleBurstPolling()
            return
        }

        let settings = settingsProvider?() ?? .default
        let savePayload = self.savePayload
        processingQueue.async {
            let result = savePayload(payload, settings)

            switch result {
            case .inserted(let item):
                Logger.debug("Inserted clip id=\(item.id), type=\(item.type)")
                NotificationCenter.default.post(name: .clipLiteDidInsertClip, object: item)
            case .ignored(let reason):
                Logger.debug("Ignored clip: \(reason)")
            case .failed(let reason):
                Logger.error("Failed to save clip: \(reason)")
            }
        }

        scheduleBurstPolling()
    }

    private func scheduleBurstPolling() {
        pendingBurstPolls = burstPollIterations
        runBurstPollingStepIfNeeded()
    }

    private func runBurstPollingStepIfNeeded() {
        guard isRunning, burstPollWorkItem == nil, pendingBurstPolls > 0 else {
            return
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isRunning else { return }
            self.burstPollWorkItem = nil
            self.pendingBurstPolls = max(0, self.pendingBurstPolls - 1)
            self.pollPasteboard()
            self.runBurstPollingStepIfNeeded()
        }

        burstPollWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + burstPollingInterval, execute: work)
    }

#if DEBUG
    func pollNowForTesting() {
        pollPasteboard()
    }
#endif
}
