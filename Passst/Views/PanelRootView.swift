import AppKit
import SwiftUI

struct PanelRootView: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack(alignment: .top) {
            panelBackground

            VStack(spacing: 0) {
                PanelToolbar(model: model)
                    .frame(height: 58)

                Divider()
                    .overlay(Color.white.opacity(0.12))

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
                    .padding(.top, 66)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .clipShape(panelShape)
        .overlay {
            panelShape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.32),
                            .white.opacity(0.08),
                            .white.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .topTrailing
                    ),
                    lineWidth: 0.75
                )
        }
        .ignoresSafeArea()
    }

    private var panelShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 28,
            bottomLeadingRadius: 28,
            bottomTrailingRadius: 28,
            topTrailingRadius: 28
        )
    }

    private var panelBackground: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground)

            if #available(macOS 26.0, *) {
                panelShape
                    .fill(.clear)
                    .glassEffect(.regular, in: panelShape)
            }

            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor).opacity(0.12),
                    Color(nsColor: .windowBackgroundColor).opacity(0.055),
                    Color.accentColor.opacity(0.025)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if #unavailable(macOS 26.0) {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.045),
                        Color.black.opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    private var history: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
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
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 26)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
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
            Image(systemName: model.searchQuery.isEmpty ? "clipboard" : "magnifyingglass")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text(model.searchQuery.isEmpty ? "Copy something to begin" : "No matches")
                .font(.system(size: 15, weight: .semibold))
            Text(
                model.searchQuery.isEmpty
                    ? "Passst keeps the original clipboard formats."
                    : "Try another word or clear the search."
            )
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        .frame(width: 330, height: 210)
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
