import AppKit
import SwiftUI

struct PanelToolbar: View {
    @Bindable var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var searchFocused: Bool
    @State private var hoveredSuggestionID: String?
    @State private var toolbarMenuHovered = false

    private enum FilterSuggestion: Identifiable {
        case kind(ClipboardContentKind)
        case source(ClipboardSourceFilter)
        case date(ClipboardDateFilter)

        var id: String {
            switch self {
            case let .kind(kind): "kind:\(kind.rawValue)"
            case let .source(source): "source:\(source.id)"
            case let .date(date): "date:\(date.rawValue)"
            }
        }

        var title: String {
            switch self {
            case let .kind(kind): kind.title
            case let .source(source): source.applicationName
            case let .date(date): date.title
            }
        }

        var symbolName: String {
            switch self {
            case let .kind(kind): kind.symbolName
            case .source: "app.fill"
            case let .date(date): date.symbolName
            }
        }
    }

    private var searchExpanded: Bool {
        model.isSearchFocused
            || !model.searchQuery.isEmpty
            || model.hasActiveSearchFilters
    }

    private var searchActive: Bool {
        !model.searchQuery.isEmpty || model.hasActiveSearchFilters
    }

    private var searchAnimation: Animation {
        model.reduceMotion
            ? .easeOut(duration: 0.12)
            : .timingCurve(0.18, 0.82, 0.22, 1, duration: 0.24)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                HStack(spacing: 12) {
                    searchCapsule(availableWidth: geometry.size.width)
                        .overlay(alignment: .topLeading) {
                        if !filterSuggestions.isEmpty {
                            suggestionsPanel
                                .offset(y: 46)
                                .zIndex(40)
                                .transition(
                                    .move(edge: .top)
                                        .combined(with: .opacity)
                                )
                        }
                    }
                    .zIndex(40)

                    CategoryBar(model: model, compact: searchExpanded)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxHeight: 40)
                }
                .frame(maxWidth: geometry.size.width - 96, alignment: .center)
                .zIndex(20)

                HStack {
                    Spacer()
                    toolbarMenu
                }
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: model.isSearchFocused) { _, focused in
            if focused {
                Task { @MainActor in
                    await Task.yield()
                    guard model.isSearchFocused else { return }
                    searchFocused = true
                }
            } else {
                searchFocused = false
            }
        }
        .animation(.easeOut(duration: 0.13), value: filterSuggestions.map(\.id))
    }

    private func searchCapsule(availableWidth: CGFloat) -> some View {
        let width = searchExpanded
            ? min(520, max(400, availableWidth * 0.34))
            : 32

        return HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    searchActive
                        ? Color.accentColor
                        : Color.primary.opacity(0.64)
                )

            if searchExpanded {
                activeFilterChips
            }

            if searchExpanded {
                TextField("Search history", text: $model.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .regular))
                    .focused($searchFocused)
                    .tint(Color.accentColor)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .offset(x: -5)))
            }

            if searchExpanded, searchActive {
                Button {
                    model.searchQuery = ""
                    model.clearSearchFilters()
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.primary.opacity(0.48))
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .transition(.scale(scale: 0.75).combined(with: .opacity))
            }

            if searchExpanded {
                filterMenu
            }
        }
        .padding(.horizontal, searchExpanded ? 12 : 0)
        .frame(width: width, height: searchExpanded ? 40 : 32)
        .background {
            if searchExpanded {
                Capsule().fill(
                    Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.07)
                )
            }
        }
        .overlay {
            if searchExpanded && model.isSearchFocused {
                Capsule()
                    .stroke(Color.accentColor, lineWidth: 2.5)
            }
        }
        .shadow(
            color: .black.opacity(model.isSearchFocused ? 0.11 : 0),
            radius: 10,
            y: 4
        )
        .contentShape(Capsule())
        .onTapGesture {
            guard !searchExpanded else { return }
            activateSearch()
        }
        .accessibilityLabel(searchExpanded ? "Search history" : "Search")
        .help(searchExpanded ? "Search history" : "Search")
        .animation(searchAnimation, value: searchExpanded)
        .animation(.easeOut(duration: 0.12), value: searchActive)
    }

    @ViewBuilder
    private var activeFilterChips: some View {
        if !model.searchFilters.kinds.isEmpty {
            filterChip(
                title: model.searchFilters.kinds.count == 1
                    ? model.searchFilters.kinds.first?.title ?? "Type"
                    : "\(model.searchFilters.kinds.count) Types",
                symbol: model.searchFilters.kinds.count == 1
                    ? model.searchFilters.kinds.first?.symbolName ?? "doc"
                    : "square.stack.3d.up"
            ) {
                model.clearContentKindFilters()
            }
        }

        if let source = model.searchFilters.source {
            filterChip(
                title: source.applicationName,
                symbol: "app.fill"
            ) {
                model.setSourceFilter(nil)
            }
        }

        if let date = model.searchFilters.date {
            filterChip(title: date.title, symbol: date.symbolName) {
                model.setDateFilter(nil)
            }
        }
    }

    private func filterChip(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12.5, weight: .medium))
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Color.accentColor.opacity(0.16), in: Capsule())
        }
        .buttonStyle(.plain)
        .help("Remove \(title) filter")
    }

    private var filterMenu: some View {
        Menu {
            Menu("Content Type") {
                ForEach(ClipboardContentKind.allCases, id: \.rawValue) { kind in
                    Button {
                        model.toggleContentKindFilter(kind)
                    } label: {
                        Label(
                            kind.title,
                            systemImage: model.searchFilters.kinds.contains(kind)
                                ? "checkmark.circle.fill"
                                : kind.symbolName
                        )
                    }
                }
            }

            Menu("Source App") {
                Button {
                    model.setSourceFilter(nil)
                } label: {
                    Label(
                        "Any App",
                        systemImage: model.searchFilters.source == nil
                            ? "checkmark.circle.fill"
                            : "square.grid.2x2"
                    )
                }
                Divider()
                if model.availableSourceApplications.isEmpty {
                    Text("No source apps yet")
                } else {
                    ForEach(model.availableSourceApplications) { source in
                        Button {
                            model.setSourceFilter(source)
                        } label: {
                            Label(
                                source.applicationName,
                                systemImage: model.searchFilters.source == source
                                    ? "checkmark.circle.fill"
                                    : "app.fill"
                            )
                        }
                    }
                }
            }

            Menu("Date") {
                Button {
                    model.setDateFilter(nil)
                } label: {
                    Label(
                        "Any Time",
                        systemImage: model.searchFilters.date == nil
                            ? "checkmark.circle.fill"
                            : "calendar"
                    )
                }
                Divider()
                ForEach(ClipboardDateFilter.allCases) { date in
                    Button {
                        model.setDateFilter(date)
                    } label: {
                        Label(
                            date.title,
                            systemImage: model.searchFilters.date == date
                                ? "checkmark.circle.fill"
                                : date.symbolName
                        )
                    }
                }
            }

            if model.hasActiveSearchFilters {
                Divider()
                Button("Clear Filters") {
                    model.clearSearchFilters()
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(
                    model.hasActiveSearchFilters
                        ? Color.accentColor
                        : Color.secondary
                )
                .frame(width: 28, height: 28)
                .background(
                    model.hasActiveSearchFilters
                        ? Color.accentColor.opacity(0.13)
                        : Color.clear,
                    in: Circle()
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Filter by type, source app, or date")
    }

    private func activateSearch() {
        withAnimation(searchAnimation) {
            model.isSearchFocused = true
        }
    }

    private var filterSuggestions: [FilterSuggestion] {
        guard model.isSearchFocused else { return [] }
        let query = model.searchQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !query.isEmpty else { return [] }

        let kinds: [FilterSuggestion] = ClipboardContentKind.allCases.compactMap { kind in
            guard !model.searchFilters.kinds.contains(kind),
                  kind.title.lowercased().hasPrefix(query)
            else {
                return nil
            }
            return FilterSuggestion.kind(kind)
        }
        let sources: [FilterSuggestion] = model.availableSourceApplications.compactMap { source in
            guard model.searchFilters.source != source,
                  source.applicationName.lowercased().hasPrefix(query)
            else {
                return nil
            }
            return FilterSuggestion.source(source)
        }
        let dates: [FilterSuggestion] = ClipboardDateFilter.allCases.compactMap { date in
            guard model.searchFilters.date != date,
                  date.title.lowercased().hasPrefix(query)
            else {
                return nil
            }
            return FilterSuggestion.date(date)
        }
        return Array((kinds + sources + dates).prefix(5))
    }

    private var suggestionsPanel: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(filterSuggestions) { suggestion in
                Button {
                    apply(suggestion)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: suggestion.symbolName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 18)
                        Text(suggestion.title)
                            .font(.system(size: 14, weight: .regular))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(
                        Color.accentColor.opacity(
                            hoveredSuggestionID == suggestion.id ? 0.13 : 0
                        ),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    hoveredSuggestionID = isHovered ? suggestion.id : nil
                }
            }
        }
        .padding(6)
        .frame(width: 280)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
    }

    private func apply(_ suggestion: FilterSuggestion) {
        switch suggestion {
        case let .kind(kind):
            model.toggleContentKindFilter(kind)
        case let .source(source):
            model.setSourceFilter(source)
        case let .date(date):
            model.setDateFilter(date)
        }
        model.searchQuery = ""
        searchFocused = true
    }

    private var toolbarMenu: some View {
        Menu {
            Button {
                model.toggleMonitoring()
            } label: {
                Label(
                    model.monitorPaused
                        ? "Resume Clipboard History"
                        : "Pause Clipboard History",
                    systemImage: model.monitorPaused ? "play.fill" : "pause.fill"
                )
            }

            Divider()

            Button {
                model.showSettings()
            } label: {
                Label("Settings…", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: model.monitorPaused ? "play.fill" : "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(
                    model.monitorPaused
                        ? Color.orange
                        : Color.primary.opacity(0.66)
                )
                .frame(width: 32, height: 32)
                .background(
                    Color.primary.opacity(toolbarMenuHovered ? 0.075 : 0),
                    in: Circle()
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { toolbarMenuHovered = $0 }
        .help(model.monitorPaused ? "History paused" : "Passst menu")
    }
}
