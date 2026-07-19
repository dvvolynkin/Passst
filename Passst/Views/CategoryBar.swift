import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CategoryBar: View {
    @Bindable var model: AppModel
    let compact: Bool

    @State private var creatingCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryColor = ClipboardCategory.palette[4]
    @State private var targetedCategoryID: UUID?
    @State private var hoveredCategoryID: String?
    @State private var plusHovered = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: compact ? 8 : 18) {
                categoryButton(
                    title: "Clipboard",
                    color: Color.primary.opacity(0.72),
                    systemImage: "clock.arrow.circlepath",
                    selected: model.selectedCategoryID == nil
                ) {
                    model.selectedCategoryID = nil
                }

                ForEach(model.categories) { category in
                    categoryButton(
                        title: category.name,
                        color: Color(categoryHex: category.colorHex),
                        selected: model.selectedCategoryID == category.id,
                        dropTargeted: targetedCategoryID == category.id
                    ) {
                        model.selectedCategoryID = category.id
                    }
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
                        Button("Delete Pinboard", role: .destructive) {
                            model.deleteCategory(category)
                        }
                    }
                }

                if !compact {
                    Button {
                        creatingCategory = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .regular))
                            .frame(width: 32, height: 32)
                            .background(
                                Color.primary.opacity(plusHovered ? 0.075 : 0),
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { plusHovered = $0 }
                    .help("Create pinboard")
                    .popover(isPresented: $creatingCategory, arrowEdge: .bottom) {
                        categoryCreator
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(height: 40)
        .scrollIndicators(.hidden)
        .animation(.easeOut(duration: 0.16), value: compact)
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
                        .font(.system(size: compact ? 14 : 13, weight: .medium))
                        .frame(width: 14)
                } else {
                    Circle()
                        .fill(color)
                        .frame(width: compact ? 10 : 9, height: compact ? 10 : 9)
                }

                if !compact {
                    Text(title)
                        .lineLimit(1)
                }
            }
            .font(.system(size: 14, weight: selected ? .semibold : .medium))
            .foregroundStyle(
                selected
                    ? Color.primary.opacity(0.92)
                    : Color.primary.opacity(0.68)
            )
            .padding(.horizontal, compact ? 0 : 10)
            .frame(width: compact ? 30 : nil, height: 32)
            .background(
                dropTargeted
                    ? color.opacity(0.22)
                    : selected
                        ? Color.primary.opacity(0.105)
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

    private var categoryCreator: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Pinboard")
                .font(.headline)

            TextField("Name", text: $newCategoryName)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
                .onSubmit(createCategory)

            HStack(spacing: 9) {
                ForEach(ClipboardCategory.palette, id: \.self) { colorHex in
                    Button {
                        newCategoryColor = colorHex
                    } label: {
                        Circle()
                            .fill(Color(categoryHex: colorHex))
                            .frame(width: 20, height: 20)
                            .overlay {
                                if newCategoryColor == colorHex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    creatingCategory = false
                    resetCreator()
                }
                Button("Create", action: createCategory)
                    .keyboardShortcut(.defaultAction)
                    .disabled(
                        newCategoryName
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )
            }
        }
        .padding(16)
        .frame(width: 280)
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                nameFocused = true
            }
        }
    }

    private func createCategory() {
        guard model.addCategory(
            name: newCategoryName,
            colorHex: newCategoryColor
        ) != nil else {
            return
        }
        creatingCategory = false
        resetCreator()
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

    private func resetCreator() {
        newCategoryName = ""
        newCategoryColor = ClipboardCategory.palette[4]
    }
}
