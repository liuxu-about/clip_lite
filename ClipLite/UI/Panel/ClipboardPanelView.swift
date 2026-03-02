import AppKit
import SwiftUI

struct ClipboardPanelView: View {
    private static let listWidth: CGFloat = 360
    private static let panelHeight: CGFloat = 372
    private static let detailWidth: CGFloat = 380
    private static let totalWidth: CGFloat = listWidth + detailWidth + 8
    private static let previewHoverDelayNanoseconds: UInt64 = 900_000_000
    private static let keyboardScrollAnimationDuration = 0.12
    private static let hoverSuppressionAfterKeyboardNanoseconds: UInt64 = 220_000_000

    @ObservedObject var viewModel: ClipboardPanelViewModel
    let onConfirmSelection: () -> Void
    @FocusState private var isSearchFieldFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredItemID: UUID?
    @State private var pendingPreviewTask: Task<Void, Never>?
    @State private var pendingHoverSuppressionTask: Task<Void, Never>?
    @State private var isHoverSelectionSuppressed = false
    @State private var scrollEventMonitor: Any?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            panelSurface

            if let item = viewModel.previewedItem {
                detailPane(for: item)
                    .frame(width: Self.detailWidth, alignment: .leading)
                    .padding(.top, 22)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                Spacer()
                    .frame(width: Self.detailWidth)
            }
        }
        .frame(width: Self.totalWidth, height: Self.panelHeight, alignment: .leading)
        .animation(.easeInOut(duration: 0.14), value: viewModel.previewedItemID)
        .onChange(of: viewModel.searchFocusTick) { _ in
            DispatchQueue.main.async {
                isSearchFieldFocused = true
            }
        }
        .onChange(of: isSearchFieldFocused) { focused in
            viewModel.setSearchFieldFocused(focused)
            if focused {
                viewModel.enterSearchMode()
            } else if viewModel.searchText.isEmpty {
                viewModel.exitSearchMode()
            }
        }
        .onChange(of: viewModel.isSearchMode) { isSearchMode in
            if !isSearchMode {
                isSearchFieldFocused = false
            }
            clearPreviewState()
        }
        .onChange(of: viewModel.searchText) { _ in
            clearPreviewState()
        }
        .onChange(of: viewModel.activeFilter) { _ in
            clearPreviewState()
        }
        .onChange(of: viewModel.previewedItemID) { previewedItemID in
            if previewedItemID == nil {
                cancelPendingPreviewTask()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSScrollView.didLiveScrollNotification)) { _ in
            clearPreviewState()
        }
        .onAppear {
            installScrollEventMonitorIfNeeded()
        }
        .onDisappear {
            clearPreviewState()
            cancelHoverSuppressionTask()
            removeScrollEventMonitor()
            viewModel.setSearchFieldFocused(false)
        }
    }

    private var panelSurface: some View {
        ScrollViewReader { scrollProxy in
            VStack(spacing: 0) {
                if viewModel.items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                                row(item: item, index: index)
                                    .id(item.id)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                        .padding(.bottom, 2)
                    }
                }

                Divider()
                    .overlay(adaptive(Color.white.opacity(0.08), Color.black.opacity(0.08)))

                footer
            }
            .onChange(of: viewModel.keyboardNavigationTick) { _ in
                handleKeyboardNavigationSelectionChange(scrollProxy: scrollProxy)
            }
        }
        .frame(width: Self.listWidth, height: Self.panelHeight)
        .background(backgroundLayer)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(adaptive(Color.white.opacity(0.1), Color.black.opacity(0.14)), lineWidth: 1)
        )
        .shadow(color: adaptive(.black.opacity(0.22), .black.opacity(0.12)), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private func row(item: ClipItem, index: Int) -> some View {
        let selected = viewModel.selectedIndex == index

        HStack(spacing: 8) {
            // Number label
            shortcutLabel(index: index, selected: selected)
                .frame(width: 21)

            // Icon/Thumbnail
            leadingView(for: item, selected: selected)

            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(item.textPreview)
                    .font(.system(size: 12, weight: .regular))
                    .lineLimit(1)
                    .foregroundStyle(selected ? Color.white : adaptive(Color.white.opacity(0.9), Color.primary.opacity(0.88)))
                    .multilineTextAlignment(.leading)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(selected ? Color.blue.opacity(0.85) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            _ = viewModel.select(index: index)
        }
        .onHover { isHovering in
            handleHover(isHovering: isHovering, itemID: item.id, index: index)
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            viewModel.select(index: index)
            onConfirmSelection()
        })
    }

    @ViewBuilder
    private func leadingView(for item: ClipItem, selected: Bool) -> some View {
        if item.type == .image {
            let image = viewModel.thumbnail(for: item)

            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(selected ? Color.white.opacity(0.9) : adaptive(Color.white.opacity(0.6), Color.black.opacity(0.55)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selected ? adaptive(Color.white.opacity(0.15), Color.black.opacity(0.12)) : adaptive(Color.white.opacity(0.05), Color.black.opacity(0.06)))
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(selected ? Color.white.opacity(0.95) : adaptive(Color.white.opacity(0.7), Color.black.opacity(0.65)))
                .frame(width: 30, height: 30)
        }
    }

    @ViewBuilder
    private func shortcutLabel(index: Int, selected: Bool) -> some View {
        if index < 9 {
            Text("\(index + 1)")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(selected ? Color.white.opacity(0.95) : adaptive(Color.white.opacity(0.4), Color.black.opacity(0.4)))
        } else {
            Color.clear
                .frame(width: 1, height: 1)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                filterButton(title: "All", filter: .all)
                filterButton(title: "Text", filter: .text)
                filterButton(title: "Image", filter: .image)
            }

            Spacer()

            searchBar
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(adaptive(Color.black.opacity(0.3), Color.black.opacity(0.04)))
    }

    @ViewBuilder
    private func filterButton(title: String, filter: ClipboardPanelViewModel.ItemFilter) -> some View {
        let isActive = viewModel.activeFilter == filter

        HStack(spacing: 5) {
            Circle()
                .fill(isActive ? Color.blue : adaptive(Color.white.opacity(0.3), Color.black.opacity(0.22)))
                .frame(width: 7, height: 7)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isActive ? adaptive(Color.white, Color.blue.opacity(0.9)) : adaptive(Color.white.opacity(0.6), Color.black.opacity(0.63)))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3.5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActive ? adaptive(Color.white.opacity(0.08), Color.blue.opacity(0.14)) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.setFilter(filter)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(adaptive(Color.white.opacity(0.5), Color.black.opacity(0.45)))
            Text("No Clipboard History")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(adaptive(Color.white.opacity(0.85), Color.black.opacity(0.86)))
            Text("Copy text or image, then press your global hotkey")
                .font(.system(size: 12.5))
                .foregroundStyle(adaptive(Color.white.opacity(0.55), Color.black.opacity(0.56)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var backgroundLayer: some View {
        ZStack {
            VisualEffectView(material: colorScheme == .dark ? .hudWindow : .popover, blendingMode: .withinWindow)
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.black.opacity(0.26), Color.black.opacity(0.45)]
                    : [Color.white.opacity(0.78), Color(red: 0.90, green: 0.93, blue: 0.98).opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isSearchFieldFocused ? Color.blue : adaptive(Color.white.opacity(0.5), Color.black.opacity(0.5)))

            TextField("Search (Cmd+F)", text: searchTextBinding)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isSearchFieldFocused)
                .onSubmit {
                    onConfirmSelection()
                }
                .frame(width: 104)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.updateSearchText("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(adaptive(Color.white.opacity(0.4), Color.black.opacity(0.35)))
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(adaptive(Color.black.opacity(0.4), Color.black.opacity(0.06)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSearchFieldFocused ? Color.blue.opacity(0.6) : adaptive(Color.white.opacity(0.15), Color.black.opacity(0.14)), lineWidth: 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            DispatchQueue.main.async {
                isSearchFieldFocused = true
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSearchFieldFocused)
    }

    @ViewBuilder
    private func detailPane(for item: ClipItem) -> some View {
        if item.type == .image {
            imagePreviewBubble(for: item)
        } else {
            textDetailBubble(for: item)
        }
    }

    private func textDetailBubble(for item: ClipItem) -> some View {
        bubbleContainer {
            VStack(alignment: .leading, spacing: 7) {
                Text(detailTitle(for: item))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(adaptive(Color.white, Color.black.opacity(0.88)))
                    .multilineTextAlignment(.leading)
                    .lineLimit(12)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(detailSubtitle(for: item))
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(adaptive(Color.white.opacity(0.72), Color.black.opacity(0.58)))
            }
        }
    }

    private func imagePreviewBubble(for item: ClipItem) -> some View {
        let previewImage = viewModel.previewImage(for: item)
        let previewSize = imagePreviewSize(for: item, image: previewImage)

        return bubbleContainer(contentWidth: previewSize.width) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(adaptive(Color.black.opacity(0.28), Color.black.opacity(0.08)))

                    if let image = previewImage {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .padding(6)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .tint(adaptive(.white.opacity(0.8), .black.opacity(0.45)))
                    }
                }
                .frame(width: previewSize.width, height: previewSize.height)
            }
        }
    }

    private func bubbleContainer<Content: View>(
        contentWidth: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let bubbleTint = adaptive(
            Color(red: 0.18, green: 0.22, blue: 0.30).opacity(0.42),
            Color(red: 0.90, green: 0.94, blue: 0.99).opacity(0.84)
        )
        let bubbleStroke = adaptive(Color.white.opacity(0.16), Color.black.opacity(0.12))

        return HStack(spacing: 0) {
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .withinWindow)
                BubblePointer().fill(bubbleTint)
            }
            .clipShape(BubblePointer())
            .frame(width: 12, height: 18)
            .overlay(
                BubblePointer()
                    .stroke(bubbleStroke, lineWidth: 1)
            )

            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(width: contentWidth.map { $0 + 28 }, alignment: .leading)
                .frame(maxWidth: contentWidth == nil ? Self.detailWidth - 12 : nil, alignment: .leading)
                .background(
                    ZStack {
                        VisualEffectView(material: .popover, blendingMode: .withinWindow)
                        bubbleTint
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(bubbleStroke, lineWidth: 1)
                )
        }
        .shadow(color: adaptive(.black.opacity(0.18), .black.opacity(0.1)), radius: 6, x: 0, y: 2)
        .allowsHitTesting(false)
    }

    private func detailTitle(for item: ClipItem) -> String {
        if let textContent = item.textContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           !textContent.isEmpty {
            return textContent
        }
        return item.textPreview
    }

    private func detailSubtitle(for item: ClipItem) -> String {
        item.createdAt.formatted(date: .omitted, time: .shortened)
    }

    private func imagePreviewSize(for item: ClipItem, image: NSImage?) -> CGSize {
        let sourceSize: CGSize
        if let image {
            sourceSize = image.size
        } else if let w = item.imageWidth, let h = item.imageHeight, w > 0, h > 0 {
            sourceSize = CGSize(width: w, height: h)
        } else {
            return CGSize(width: maxImagePreviewWidth, height: 220)
        }

        let fitted = fittedSize(
            source: sourceSize,
            maxSize: CGSize(width: maxImagePreviewWidth, height: maxImagePreviewHeight)
        )

        return CGSize(
            width: max(110, fitted.width),
            height: max(120, fitted.height)
        )
    }

    private func fittedSize(source: CGSize, maxSize: CGSize) -> CGSize {
        guard source.width > 0, source.height > 0 else {
            return maxSize
        }

        let widthScale = maxSize.width / source.width
        let heightScale = maxSize.height / source.height
        let scale = min(widthScale, heightScale, 1)

        return CGSize(
            width: floor(source.width * scale),
            height: floor(source.height * scale)
        )
    }

    private var maxImagePreviewWidth: CGFloat {
        Self.detailWidth - 12 - 28
    }

    private var maxImagePreviewHeight: CGFloat {
        268
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { viewModel.searchText },
            set: { value in
                if !viewModel.isSearchMode {
                    viewModel.enterSearchMode()
                }
                viewModel.updateSearchText(value)
            }
        )
    }

    private func adaptive(_ dark: Color, _ light: Color) -> Color {
        colorScheme == .dark ? dark : light
    }

    private func handleHover(isHovering: Bool, itemID: UUID, index: Int) {
        if isHovering {
            guard !isHoverSelectionSuppressed else {
                return
            }
            hoveredItemID = itemID
            _ = viewModel.select(index: index)
            schedulePreview(for: itemID, requireHoverMatch: true)
            return
        }

        if hoveredItemID == itemID {
            hoveredItemID = nil
        }

        cancelPendingPreviewTask()

        if viewModel.previewedItemID == itemID {
            viewModel.clearPreview()
        }
    }

    private func schedulePreview(for itemID: UUID, requireHoverMatch: Bool) {
        cancelPendingPreviewTask()
        pendingPreviewTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: Self.previewHoverDelayNanoseconds)
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }
            if requireHoverMatch, hoveredItemID != itemID {
                return
            }
            viewModel.showPreview(for: itemID)
        }
    }

    private func clearPreviewState() {
        hoveredItemID = nil
        cancelPendingPreviewTask()
        viewModel.clearPreview()
    }

    private func cancelPendingPreviewTask() {
        pendingPreviewTask?.cancel()
        pendingPreviewTask = nil
    }

    private func installScrollEventMonitorIfNeeded() {
        guard scrollEventMonitor == nil else {
            return
        }

        scrollEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard event.window is ClipboardPanel else {
                return event
            }
            guard shouldAllowScroll(event) else {
                return nil
            }
            return event
        }
    }

    private func removeScrollEventMonitor() {
        guard let scrollEventMonitor else {
            return
        }
        NSEvent.removeMonitor(scrollEventMonitor)
        self.scrollEventMonitor = nil
    }

    private func shouldAllowScroll(_ event: NSEvent) -> Bool {
        ScrollEventPolicy.shouldAllowScroll(
            scrollingDeltaX: event.scrollingDeltaX,
            scrollingDeltaY: event.scrollingDeltaY,
            phase: event.phase,
            momentumPhase: event.momentumPhase
        )
    }

    private func cancelHoverSuppressionTask() {
        pendingHoverSuppressionTask?.cancel()
        pendingHoverSuppressionTask = nil
        isHoverSelectionSuppressed = false
    }

    private func suppressHoverSelectionAfterKeyboardNavigation() {
        pendingHoverSuppressionTask?.cancel()
        pendingHoverSuppressionTask = nil
        isHoverSelectionSuppressed = true

        pendingHoverSuppressionTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: Self.hoverSuppressionAfterKeyboardNanoseconds)
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }
            isHoverSelectionSuppressed = false
            pendingHoverSuppressionTask = nil
        }
    }

    private func handleKeyboardNavigationSelectionChange(scrollProxy: ScrollViewProxy) {
        suppressHoverSelectionAfterKeyboardNavigation()
        hoveredItemID = nil
        cancelPendingPreviewTask()
        viewModel.clearPreview()

        guard let selectedItemID = viewModel.selectedItem?.id else {
            return
        }

        withAnimation(.easeInOut(duration: Self.keyboardScrollAnimationDuration)) {
            scrollProxy.scrollTo(selectedItemID, anchor: .center)
        }

        guard !viewModel.isSearchFieldFocused else {
            return
        }
        schedulePreview(for: selectedItemID, requireHoverMatch: false)
    }
}

private struct BubblePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}
