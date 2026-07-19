import AppKit
import SwiftUI

struct PanelRootView: View {
    @Bindable var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .top) {
            panelBackground

            VStack(spacing: 0) {
                PanelToolbar(model: model)
                    .frame(height: PassstStyle.toolbarHeight)
                    .zIndex(30)

                history
            }

            if let previewedID = model.previewedID,
               let record = model.records.first(where: { $0.id == previewedID }) {
                PreviewOverlay(
                    model: model,
                    record: record,
                    payload: model.previewPayload
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(10)
            }

            if let notice = model.notice {
                NoticeView(notice: notice)
                    .padding(.top, PassstStyle.toolbarHeight - 2)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .clipShape(panelShape)
        .ignoresSafeArea()
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: PassstStyle.panelCornerRadius,
            style: .continuous
        )
    }

    private var panelBackground: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground)
            Color.black.opacity(colorScheme == .dark ? 0.14 : 0.015)
        }
    }

    private var history: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: PassstStyle.cardSpacing) {
                    if model.records.isEmpty, !model.isLoading {
                        emptyState
                    }

                    ForEach(model.records) { record in
                        ClipboardCardView(
                            model: model,
                            record: record
                        )
                        .id(record.id)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .offset(x: 12)),
                                removal: .opacity.combined(with: .scale(scale: 0.985))
                            )
                        )
                        .onAppear {
                            model.loadMoreIfNeeded(visibleRecord: record)
                        }
                    }

                    if model.isLoading && (model.records.isEmpty || model.hasMore) {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 60)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, PassstStyle.panelHorizontalPadding)
                .padding(.top, PassstStyle.historyTopPadding)
                .padding(.bottom, PassstStyle.historyBottomPadding)
            }
            .scrollIndicators(.hidden)
            .onChange(of: model.selection.focusedID) { _, focusedID in
                guard let focusedID else { return }
                withAnimation(
                    model.reduceMotion ? .easeOut(duration: 0.1) : .smooth(duration: 0.16)
                ) {
                    proxy.scrollTo(focusedID)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(
                systemName: model.searchQuery.isEmpty && !model.hasActiveSearchFilters
                    ? "clipboard"
                    : "magnifyingglass"
            )
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text(emptyStateTitle)
                .font(.system(size: 15, weight: .semibold))
            Text(
                emptyStateMessage
            )
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        .frame(width: 330, height: 210)
    }

    private var emptyStateTitle: String {
        if !model.searchQuery.isEmpty || model.hasActiveSearchFilters {
            return "No matches"
        }
        if model.selectedCategoryID != nil {
            return "This pinboard is empty"
        }
        return "Copy something to begin"
    }

    private var emptyStateMessage: String {
        if !model.searchQuery.isEmpty || model.hasActiveSearchFilters {
            return "Try another query or remove a filter."
        }
        if model.selectedCategoryID != nil {
            return "Drag a card onto this pinboard, or assign it from the context menu."
        }
        return "Passst keeps the original clipboard formats."
    }
}

private struct NoticeView: View {
    let notice: PanelNotice

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: notice.symbol)
            Text(notice.message)
                .lineLimit(2)
        }
        .font(.system(size: 12.5, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            notice.isError
                ? Color.red.opacity(0.92)
                : Color.black.opacity(0.78),
            in: Capsule()
        )
        .shadow(color: .black.opacity(0.22), radius: 12, y: 4)
        .frame(maxWidth: 620)
    }
}
