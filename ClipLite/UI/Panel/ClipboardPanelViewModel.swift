import AppKit
import Combine
import Foundation

@MainActor
final class ClipboardPanelViewModel: ObservableObject {
    enum ItemFilter: String, CaseIterable {
        case all
        case text
        case image

        func matches(_ item: ClipItem) -> Bool {
            switch self {
            case .all:
                return true
            case .text:
                return item.type == .text
            case .image:
                return item.type == .image
            }
        }
    }

    @Published private(set) var items: [ClipItem] = []
    @Published private(set) var totalItemCount = 0
    @Published private(set) var selectedIndex: Int?
    @Published private(set) var previewedItemID: UUID?
    @Published private(set) var thumbnailCache: [UUID: NSImage] = [:]
    @Published private(set) var previewCache: [UUID: NSImage] = [:]
    @Published private(set) var isSearchMode = false
    @Published private(set) var searchText = ""
    @Published private(set) var searchFocusTick = 0
    @Published private(set) var isSearchFieldFocused = false
    @Published private(set) var keyboardNavigationTick = 0
    @Published private(set) var activeFilter: ItemFilter = .all

    private var allItems: [ClipItem] = []
    private var loadingThumbnailIDs: Set<UUID> = []
    private var loadingPreviewIDs: Set<UUID> = []
    private let thumbnailLoadQueue = DispatchQueue(
        label: "com.cliplite.panel.thumbnail-loader",
        qos: .userInitiated
    )

    var selectedItem: ClipItem? {
        guard let selectedIndex, items.indices.contains(selectedIndex) else {
            return nil
        }
        return items[selectedIndex]
    }

    var previewedItem: ClipItem? {
        guard let previewedItemID else {
            return nil
        }
        return items.first(where: { $0.id == previewedItemID })
    }

    func setItems(_ newItems: [ClipItem]) {
        allItems = newItems
        totalItemCount = newItems.count
        trimCachesForCurrentItems()
        applyFilter(keepCurrentSelection: true)
    }

    func selectFirstItem() {
        selectedIndex = items.isEmpty ? nil : 0
    }

    func moveSelectionUp() {
        guard let selectedIndex else {
            self.selectedIndex = items.isEmpty ? nil : 0
            return
        }
        self.selectedIndex = max(0, selectedIndex - 1)
    }

    func moveSelectionDown() {
        guard !items.isEmpty else {
            selectedIndex = nil
            return
        }
        guard let selectedIndex else {
            self.selectedIndex = 0
            return
        }
        self.selectedIndex = min(items.count - 1, selectedIndex + 1)
    }

    @discardableResult
    func select(index: Int) -> Bool {
        guard items.indices.contains(index) else { return false }
        selectedIndex = index
        return true
    }

    func showPreview(for itemID: UUID) {
        guard items.contains(where: { $0.id == itemID }) else {
            return
        }
        previewedItemID = itemID
    }

    func clearPreview() {
        previewedItemID = nil
    }

    @discardableResult
    func togglePreviewForSelectedItem() -> Bool {
        guard let selectedItem else {
            return false
        }

        if previewedItemID == selectedItem.id {
            previewedItemID = nil
        } else {
            previewedItemID = selectedItem.id
        }
        return true
    }

    func setSearchFieldFocused(_ focused: Bool) {
        isSearchFieldFocused = focused
    }

    func notifyKeyboardNavigation() {
        keyboardNavigationTick &+= 1
    }

    func enterSearchMode() {
        guard !isSearchMode else {
            return
        }

        isSearchMode = true
        applyFilter(keepCurrentSelection: true)
    }

    func exitSearchMode() {
        guard isSearchMode || !searchText.isEmpty else {
            return
        }

        isSearchMode = false
        searchText = ""
        applyFilter(keepCurrentSelection: true)
    }

    func updateSearchText(_ rawValue: String) {
        if rawValue == searchText {
            return
        }

        searchText = rawValue
        applyFilter(keepCurrentSelection: false)
    }

    func setFilter(_ filter: ItemFilter) {
        guard filter != activeFilter else {
            return
        }

        activeFilter = filter
        applyFilter(keepCurrentSelection: false)
    }

    func activateSearchFromShortcut() {
        enterSearchMode()
        searchFocusTick &+= 1
    }

    func thumbnail(for item: ClipItem) -> NSImage? {
        guard item.type == .image else {
            return nil
        }

        if let cached = thumbnailCache[item.id] {
            return cached
        }

        loadThumbnailIfNeeded(for: item)
        return nil
    }

    func previewImage(for item: ClipItem) -> NSImage? {
        guard item.type == .image else {
            return nil
        }

        if let cached = previewCache[item.id] {
            return cached
        }

        loadPreviewIfNeeded(for: item)
        return thumbnailCache[item.id]
    }

    private func applyFilter(keepCurrentSelection: Bool) {
        let selectedID: UUID? = keepCurrentSelection ? selectedItem?.id : nil
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var filtered = allItems.filter { activeFilter.matches($0) }

        if !keyword.isEmpty {
            filtered = filtered.filter { item in
                if let textContent = item.textContent,
                   textContent.localizedCaseInsensitiveContains(keyword) {
                    return true
                }

                return item.textPreview.localizedCaseInsensitiveContains(keyword)
            }
        }

        items = filtered

        if let selectedID,
           let matchedIndex = items.firstIndex(where: { $0.id == selectedID }) {
            selectedIndex = matchedIndex
        } else {
            selectedIndex = items.isEmpty ? nil : 0
        }

        if let previewedItemID,
           !items.contains(where: { $0.id == previewedItemID }) {
            self.previewedItemID = nil
        }

        prefetchTopImageThumbnails()
    }

    private func prefetchTopImageThumbnails(maxCount: Int = 40) {
        var scheduled = 0
        for item in items where item.type == .image {
            if thumbnailCache[item.id] != nil || loadingThumbnailIDs.contains(item.id) {
                continue
            }
            loadThumbnailIfNeeded(for: item)
            scheduled += 1
            if scheduled >= maxCount {
                break
            }
        }
    }

    private func trimCachesForCurrentItems() {
        let validIDs = Set(allItems.map(\.id))
        thumbnailCache = thumbnailCache.filter { validIDs.contains($0.key) }
        previewCache = previewCache.filter { validIDs.contains($0.key) }
        loadingThumbnailIDs = Set(loadingThumbnailIDs.filter { validIDs.contains($0) })
        loadingPreviewIDs = Set(loadingPreviewIDs.filter { validIDs.contains($0) })
    }

    private func loadThumbnailIfNeeded(for item: ClipItem) {
        guard item.type == .image else { return }
        guard thumbnailCache[item.id] == nil else { return }
        guard !loadingThumbnailIDs.contains(item.id) else { return }
        guard let relativePath = item.thumbnailPath ?? item.imagePath else { return }

        loadingThumbnailIDs.insert(item.id)

        let itemID = item.id
        thumbnailLoadQueue.async { [relativePath] in
            let image: NSImage?
            if let absoluteURL = try? AppPaths.resolveRelativePath(relativePath) {
                image = NSImage(contentsOf: absoluteURL)
            } else {
                image = nil
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.loadingThumbnailIDs.remove(itemID)
                guard self.items.contains(where: { $0.id == itemID }) else { return }
                if let image {
                    self.thumbnailCache[itemID] = image
                }
            }
        }
    }

    private func loadPreviewIfNeeded(for item: ClipItem) {
        guard item.type == .image else { return }
        guard previewCache[item.id] == nil else { return }
        guard !loadingPreviewIDs.contains(item.id) else { return }
        guard let relativePath = item.imagePath ?? item.thumbnailPath else { return }

        loadingPreviewIDs.insert(item.id)

        let itemID = item.id
        thumbnailLoadQueue.async { [relativePath] in
            let image: NSImage?
            if let absoluteURL = try? AppPaths.resolveRelativePath(relativePath) {
                image = NSImage(contentsOf: absoluteURL)
            } else {
                image = nil
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.loadingPreviewIDs.remove(itemID)
                guard self.allItems.contains(where: { $0.id == itemID }) else { return }
                if let image {
                    self.previewCache[itemID] = image
                }
            }
        }
    }
}
