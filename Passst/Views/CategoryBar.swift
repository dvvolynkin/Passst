import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CategoryBar: View {
    @Bindable var model: AppModel
    let maximumWidth: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @State private var targetedCategoryID: UUID?
    @State private var hoveredCategoryID: String?

    var body: some View {
        HStack(spacing: 6) {
            categoryButton(
                title: "Clipboard",
                color: Color.primary.opacity(0.72),
                systemImage: "clock.arrow.circlepath",
                selected: model.selectedCategoryID == nil
            ) {
                model.selectedCategoryID = nil
            }
            .fixedSize()

            if !model.categories.isEmpty {
                Divider()
                    .frame(height: 18)
                    .opacity(0.28)

                tagScroller

                if isOverflowing {
                    allTagsMenu
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(width: railWidth, height: 36)
        .background {
            ZStack {
                if #available(macOS 26.0, *) {
                    Color.clear
                        .glassEffect(.regular, in: .capsule)
                } else {
                    Capsule()
                        .fill(.regularMaterial)
                }

                Capsule()
                    .fill(
                        Color.primary.opacity(colorScheme == .dark ? 0.075 : 0.06)
                    )

                Capsule()
                    .strokeBorder(
                        Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.135),
                        lineWidth: 1
                    )
            }
        }
        .animation(.easeOut(duration: 0.16), value: railWidth)
    }

    private var tagScroller: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(model.categories) { category in
                        categoryButton(
                            title: category.name,
                            color: Color(categoryHex: category.colorHex),
                            selected: model.selectedCategoryID == category.id,
                            dropTargeted: targetedCategoryID == category.id
                        ) {
                            model.selectedCategoryID = category.id
                        }
                        .id(category.id)
                        .onDrop(
                            of: [UTType.passstClipboardRecord.identifier],
                            isTargeted: Binding(
                                get: { targetedCategoryID == category.id },
                                set: { isTargeted in
                                    targetedCategoryID = isTargeted ? category.id : nil
                                }
                            )
                        ) { providers in
                            assignDroppedRecord(from: providers, to: category)
                        }
                        .contextMenu {
                            Button("Delete Tag", role: .destructive) {
                                model.deleteCategory(category)
                            }
                        }
                    }
                }
                .padding(.horizontal, isOverflowing ? 8 : 0)
            }
            .scrollIndicators(.hidden)
            .mask {
                if isOverflowing {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.035),
                            .init(color: .black, location: 0.90),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                } else {
                    Color.black
                }
            }
            .onChange(of: model.selectedCategoryID) { _, selectedID in
                guard let selectedID else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(selectedID, anchor: .center)
                }
            }
        }
    }

    private var allTagsMenu: some View {
        Menu {
            Button {
                model.selectedCategoryID = nil
            } label: {
                Label(
                    "Clipboard",
                    systemImage: model.selectedCategoryID == nil
                        ? "checkmark"
                        : "clock.arrow.circlepath"
                )
            }

            Divider()

            ForEach(model.categories) { category in
                Button {
                    model.selectedCategoryID = category.id
                } label: {
                    Label(
                        category.name,
                        systemImage: model.selectedCategoryID == category.id
                            ? "checkmark"
                            : "tag"
                    )
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("All \(model.categories.count)")
                Image(systemName: "chevron.down")
                    .font(.system(size: 8.5, weight: .bold))
            }
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(Color.primary.opacity(0.72))
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                Color.primary.opacity(0.045),
                in: Capsule()
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .tint(Color.primary)
        .fixedSize()
        .help("All tags")
        .accessibilityLabel("All tags")
    }

    private var rawPreferredWidth: CGFloat {
        let clipboardWidth = measuredButtonWidth("Clipboard", hasIcon: true)
        let tagWidths = model.categories.reduce(CGFloat.zero) { result, category in
            result + measuredButtonWidth(category.name, hasIcon: false)
        }
        let tagSpacing = CGFloat(max(0, model.categories.count - 1)) * 6
        let dividerAndSpacing: CGFloat = model.categories.isEmpty ? 0 : 19
        return 8 + clipboardWidth + dividerAndSpacing + tagWidths + tagSpacing
    }

    private var isOverflowing: Bool {
        rawPreferredWidth > maximumWidth
    }

    private var railWidth: CGFloat {
        min(maximumWidth, rawPreferredWidth + (isOverflowing ? 70 : 0))
    }

    private func measuredButtonWidth(_ title: String, hasIcon: Bool) -> CGFloat {
        let font = NSFont.systemFont(
            ofSize: 14,
            weight: hasIcon ? .semibold : .medium
        )
        let textWidth = (title as NSString).size(
            withAttributes: [.font: font]
        ).width
        let leadingMark: CGFloat = hasIcon ? 22 : 17
        return ceil(textWidth) + leadingMark + 20
    }

    private func categoryButton(
        title: String,
        color: Color,
        systemImage: String? = nil,
        selected: Bool,
        dropTargeted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let identifier = systemImage == nil ? title : "clipboard"
        let hovered = hoveredCategoryID == identifier

        return Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 14)
                } else {
                    Circle()
                        .fill(color)
                        .frame(width: 9, height: 9)
                }

                Text(title)
                    .lineLimit(1)
            }
            .font(.system(size: 14, weight: selected ? .semibold : .medium))
            .foregroundStyle(
                selected
                    ? Color.primary.opacity(0.92)
                    : Color.primary.opacity(0.68)
            )
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                dropTargeted
                    ? color.opacity(0.22)
                    : selected
                        ? PassstStyle.brandViolet.opacity(
                            colorScheme == .dark ? 0.18 : 0.12
                        )
                        : Color.primary.opacity(hovered ? 0.06 : 0),
                in: Capsule()
            )
            .overlay {
                if dropTargeted {
                    Capsule()
                        .stroke(color.opacity(0.9), lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            hoveredCategoryID = isHovered ? identifier : nil
        }
        .help(title)
        .animation(.easeOut(duration: 0.12), value: dropTargeted)
        .animation(.easeOut(duration: 0.12), value: hovered)
    }

    private func assignDroppedRecord(
        from providers: [NSItemProvider],
        to category: ClipboardCategory
    ) -> Bool {
        guard let provider = providers.first(
            where: {
                $0.hasItemConformingToTypeIdentifier(
                    UTType.passstClipboardRecord.identifier
                )
            }
        ) else {
            return false
        }

        provider.loadDataRepresentation(
            forTypeIdentifier: UTType.passstClipboardRecord.identifier
        ) { data, _ in
            guard let data,
                  let value = String(data: data, encoding: .utf8),
                  let recordID = UUID(uuidString: value)
            else {
                return
            }
            Task { @MainActor in
                model.assign(recordID: recordID, to: category)
            }
        }
        return true
    }

}
