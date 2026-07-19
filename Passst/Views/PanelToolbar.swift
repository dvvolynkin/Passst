import AppKit
import SwiftUI

struct PanelToolbar: View {
    @Bindable var model: AppModel
    @FocusState private var searchFocused: Bool

    private var searchExpanded: Bool {
        model.isSearchFocused || !model.searchQuery.isEmpty
    }

    private var searchAnimation: Animation {
        model.reduceMotion
            ? .easeOut(duration: 0.12)
            : .timingCurve(0.18, 0.82, 0.22, 1, duration: 0.24)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                searchCapsule(availableWidth: geometry.size.width)

                HStack {
                    PassstBrandMark(opacity: 0.2)
                        .frame(width: 32, height: 32)
                        .padding(.leading, 18)

                    Spacer()

                    HStack(spacing: 8) {
                        toolbarButton(
                            symbol: model.monitorPaused ? "play.fill" : "pause.fill",
                            help: model.monitorPaused
                                ? "Resume clipboard history"
                                : "Pause clipboard history"
                        ) {
                            model.toggleMonitoring()
                        }

                        toolbarButton(symbol: "gearshape.fill", help: "Settings") {
                            model.showSettings()
                        }
                    }
                    .padding(.trailing, 17)
                }
            }
        }
        .onChange(of: model.isSearchFocused) { _, focused in
            if focused {
                Task { @MainActor in
                    do {
                        try await Task.sleep(for: .milliseconds(55))
                    } catch {
                        return
                    }
                    guard model.isSearchFocused else { return }
                    searchFocused = true
                }
            } else {
                searchFocused = false
            }
        }
    }

    private func searchCapsule(availableWidth: CGFloat) -> some View {
        let width = searchExpanded ? min(760, availableWidth - 190) : 190

        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    model.searchQuery.isEmpty
                        ? .secondary
                        : Color.accentColor
                )

            ZStack(alignment: .leading) {
                if searchExpanded {
                    TextField("Search history", text: $model.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium))
                        .focused($searchFocused)
                        .tint(Color.accentColor)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity.combined(with: .offset(x: -5)))
                } else {
                    Text("Search history")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .offset(x: 5)))
                }
            }

            if searchExpanded, !model.searchQuery.isEmpty {
                Button {
                    model.searchQuery = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .transition(.scale(scale: 0.75).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 13)
        .frame(width: max(width, 190), height: 36)
        .background(.thinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(
                    model.isSearchFocused
                        ? Color.accentColor
                        : Color.white.opacity(0.16),
                    lineWidth: model.isSearchFocused ? 3 : 0.7
                )
        }
        .shadow(color: .black.opacity(0.11), radius: 8, y: 3)
        .contentShape(Capsule())
        .onTapGesture {
            guard !searchExpanded else { return }
            activateSearch()
        }
        .animation(searchAnimation, value: searchExpanded)
        .animation(.easeOut(duration: 0.12), value: model.searchQuery.isEmpty)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func activateSearch() {
        withAnimation(searchAnimation) {
            model.isSearchFocused = true
        }
    }

    private func toolbarButton(
        symbol: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(.thinMaterial, in: Circle())
                .overlay {
                    Circle().stroke(.white.opacity(0.16), lineWidth: 0.7)
                }
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
