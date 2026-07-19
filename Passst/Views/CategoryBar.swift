import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CategoryBar: View {
    @Bindable var model: AppModel
    @State private var creatingCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryColor = ClipboardCategory.palette[4]
    @State private var targetedCategoryID: UUID?
    @FocusState private var nameFocused: Bool

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                categoryButton(
                    title: "Clipboard",
                    color: Color.secondary,
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

                Button {
                    creatingCategory = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Create pinboard")
                .popover(isPresented: $creatingCategory, arrowEdge: .bottom) {
                    categoryCreator
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    private func categoryButton(
        title: String,
        color: Color,
        selected: Bool,
        dropTargeted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(title)
                    .lineLimit(1)
            }
            .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
            .foregroundStyle(selected ? .primary : .secondary)
            .padding(.horizontal, 10)
            .frame(height: 27)
            .background(
                selected || dropTargeted ? color.opacity(0.17) : Color.clear,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        selected || dropTargeted
                            ? color.opacity(0.82)
                            : Color.clear,
                        lineWidth: selected || dropTargeted ? 1.25 : 0
                    )
            }
            .scaleEffect(dropTargeted ? 1.045 : 1)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: dropTargeted)
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
                            .frame(width: 18, height: 18)
                            .overlay {
                                if newCategoryColor == colorHex {
                                    Circle()
                                        .stroke(.white, lineWidth: 2)
                                        .padding(2)
                                }
                            }
                            .overlay {
                                Circle()
                                    .stroke(Color.primary.opacity(0.16), lineWidth: 0.7)
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

extension Color {
    init(categoryHex value: String) {
        self.init(nsColor: NSColor(categoryHex: value))
    }
}

extension NSColor {
    convenience init(categoryHex value: String) {
        let hex = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let raw = UInt64(hex, radix: 16) ?? 0x0A84FF
        self.init(
            red: CGFloat((raw >> 16) & 0xFF) / 255,
            green: CGFloat((raw >> 8) & 0xFF) / 255,
            blue: CGFloat(raw & 0xFF) / 255,
            alpha: 1
        )
    }
}
