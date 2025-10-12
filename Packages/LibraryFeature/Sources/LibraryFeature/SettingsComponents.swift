import SwiftUI

struct SettingsToggleRow: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    @Binding var isOn: Bool
    var accessibilityIdentifier: String?
    var onToggle: ((Bool) -> Void)?

    init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        isOn: Binding<Bool>,
        accessibilityIdentifier: String? = nil,
        onToggle: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.accessibilityIdentifier = accessibilityIdentifier
        self.onToggle = onToggle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 4) {
            Toggle(title, isOn: Binding(
                get: { isOn },
                set: { newValue in
                    isOn = newValue
                    onToggle?(newValue)
                }
            ))
            .toggleStyle(.switch)
            .applyAccessibilityIdentifier(accessibilityIdentifier)

            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, subtitle == nil ? 0 : 2)
    }
}

struct SettingsSegmentedPickerRow<Selection: Hashable, Content: View>: View {
    let title: LocalizedStringKey
    @Binding var selection: Selection
    let options: [Selection]
    let optionLabel: (Selection) -> Content
    var accessibilityIdentifier: String?
    var onSelectionChange: ((Selection) -> Void)?

    init(
        _ title: LocalizedStringKey,
        selection: Binding<Selection>,
        options: [Selection],
        accessibilityIdentifier: String? = nil,
        onSelectionChange: ((Selection) -> Void)? = nil,
        @ViewBuilder optionLabel: @escaping (Selection) -> Content
    ) {
        self.title = title
        self._selection = selection
        self.options = options
        self.optionLabel = optionLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.onSelectionChange = onSelectionChange
    }

    var body: some View {
        Picker(title, selection: Binding(
            get: { selection },
            set: { newValue in
                selection = newValue
                onSelectionChange?(newValue)
            }
        )) {
            ForEach(options, id: \.self, content: optionLabel)
        }
        .pickerStyle(.segmented)
        .applyAccessibilityIdentifier(accessibilityIdentifier)
    }
}

struct SettingsPresetButton: View {
    let title: LocalizedStringKey
    var description: LocalizedStringKey?
    var accessibilityIdentifier: String?
    var isActive: Bool
    let action: () -> Void

    init(
        _ title: LocalizedStringKey,
        description: LocalizedStringKey? = nil,
        isActive: Bool,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.description = description
        self.isActive = isActive
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: description == nil ? 0 : 4) {
                    Text(title)
                        .foregroundStyle(Color.primary)
                    if let description {
                        Text(description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .applyAccessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct OptionalAccessibilityIdentifierModifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

private extension View {
    func applyAccessibilityIdentifier(_ identifier: String?) -> some View {
        modifier(OptionalAccessibilityIdentifierModifier(identifier: identifier))
    }
}
