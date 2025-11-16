import SwiftUI

struct SettingsToggleRow: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    @Binding var isOn: Bool
    var accessibilityIdentifier: String?
    var footer: LocalizedStringKey?
    var footerForegroundStyle: Color = .secondary
    var onToggle: ((Bool) -> Void)?

    init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        isOn: Binding<Bool>,
        accessibilityIdentifier: String? = nil,
        footer: LocalizedStringKey? = nil,
        footerForegroundStyle: Color = .secondary,
        onToggle: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.accessibilityIdentifier = accessibilityIdentifier
        self.footer = footer
        self.footerForegroundStyle = footerForegroundStyle
        self.onToggle = onToggle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(title, isOn: $isOn)
            .toggleStyle(.switch)
            .applyAccessibilityIdentifier(accessibilityIdentifier)
            .onChange(of: isOn) { newValue in
                onToggle?(newValue)
            }

            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(footerForegroundStyle)
            }
        }
        .padding(.vertical, (subtitle ?? footer) == nil ? 0 : 2)
    }
}

struct SettingsSegmentedPickerRow<Selection: Hashable, Content: View>: View {
    let title: LocalizedStringKey
    @Binding var selection: Selection
    let options: [Selection]
    let optionLabel: (Selection) -> Content
    var accessibilityIdentifier: String?
    var footer: LocalizedStringKey?
    var footerForegroundStyle: Color = .secondary
    var onSelectionChange: ((Selection) -> Void)?

    init(
        _ title: LocalizedStringKey,
        selection: Binding<Selection>,
        options: [Selection],
        accessibilityIdentifier: String? = nil,
        footer: LocalizedStringKey? = nil,
        footerForegroundStyle: Color = .secondary,
        onSelectionChange: ((Selection) -> Void)? = nil,
        @ViewBuilder optionLabel: @escaping (Selection) -> Content
    ) {
        self.title = title
        self._selection = selection
        self.options = options
        self.optionLabel = optionLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.footer = footer
        self.footerForegroundStyle = footerForegroundStyle
        self.onSelectionChange = onSelectionChange
    }

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self, content: optionLabel)
        }
        .pickerStyle(.segmented)
        .applyAccessibilityIdentifier(accessibilityIdentifier)
        .onChange(of: selection) { newValue in
            onSelectionChange?(newValue)
        }

        if let footer {
            Text(footer)
                .font(.footnote)
                .foregroundStyle(footerForegroundStyle)
        }
    }
}

struct SettingsPresetButton: View {
    private let titleText: Text
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
        self.titleText = Text(title)
        self.description = description
        self.isActive = isActive
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    init(
        verbatim title: String,
        description: LocalizedStringKey? = nil,
        isActive: Bool,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.titleText = Text(verbatim: title)
        self.description = description
        self.isActive = isActive
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: description == nil ? 0 : 4) {
                    titleText
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

struct SettingsSliderRow: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?
    var sliderAccessibilityIdentifier: String?
    var valueAccessibilityIdentifier: String?
    var valueFont: Font = .footnote
    var valueForegroundStyle: Color = .secondary
    var footer: LocalizedStringKey?
    var footerForegroundStyle: Color = .secondary
    var formatValue: (Double) -> String
    var onEditingChanged: ((Bool) -> Void)?

    init(
        _ title: LocalizedStringKey,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double? = nil,
        sliderAccessibilityIdentifier: String? = nil,
        valueAccessibilityIdentifier: String? = nil,
        valueFont: Font = .footnote,
        valueForegroundStyle: Color = .secondary,
        footer: LocalizedStringKey? = nil,
        footerForegroundStyle: Color = .secondary,
        formatValue: @escaping (Double) -> String,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.sliderAccessibilityIdentifier = sliderAccessibilityIdentifier
        self.valueAccessibilityIdentifier = valueAccessibilityIdentifier
        self.valueFont = valueFont
        self.valueForegroundStyle = valueForegroundStyle
        self.footer = footer
        self.footerForegroundStyle = footerForegroundStyle
        self.formatValue = formatValue
        self.onEditingChanged = onEditingChanged
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let step {
                Slider(
                    value: Binding(
                        get: { value },
                        set: { newValue in
                            value = clamp(newValue)
                        }
                    ),
                    in: range,
                    step: step,
                    onEditingChanged: { editing in
                        onEditingChanged?(editing)
                    }
                ) {
                    Text(title)
                }
                .applyAccessibilityIdentifier(sliderAccessibilityIdentifier)
            } else {
                Slider(
                    value: Binding(
                        get: { value },
                        set: { newValue in
                            value = clamp(newValue)
                        }
                    ),
                    in: range,
                    onEditingChanged: { editing in
                        onEditingChanged?(editing)
                    }
                )
                .applyAccessibilityIdentifier(sliderAccessibilityIdentifier)
            }

            Text(formatValue(value))
                .font(valueFont)
                .foregroundStyle(valueForegroundStyle)
                .applyAccessibilityIdentifier(valueAccessibilityIdentifier)

            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(footerForegroundStyle)
            }
        }
    }

    private func clamp(_ newValue: Double) -> Double {
        min(max(newValue, range.lowerBound), range.upperBound)
    }
}

struct SettingsStepperRow: View {
    let titleProvider: (Int) -> LocalizedStringKey
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    var accessibilityIdentifier: String?
    var footer: LocalizedStringKey?
    var footerForegroundStyle: Color = .secondary
    var onChange: ((Int) -> Void)?

    init(
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        step: Int = 1,
        accessibilityIdentifier: String? = nil,
        footer: LocalizedStringKey? = nil,
        footerForegroundStyle: Color = .secondary,
        onChange: ((Int) -> Void)? = nil,
        titleProvider: @escaping (Int) -> LocalizedStringKey
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.accessibilityIdentifier = accessibilityIdentifier
        self.footer = footer
        self.footerForegroundStyle = footerForegroundStyle
        self.onChange = onChange
        self.titleProvider = titleProvider
    }

    var body: some View {
        Stepper(value: Binding(
            get: { value },
            set: { newValue in
                let clamped = min(max(newValue, range.lowerBound), range.upperBound)
                value = clamped
                onChange?(clamped)
            }
        ), in: range, step: step) {
            Text(titleProvider(value))
        }
        .applyAccessibilityIdentifier(accessibilityIdentifier)

        if let footer {
            Text(footer)
                .font(.footnote)
                .foregroundStyle(footerForegroundStyle)
        }
    }
}

struct SettingsPickerRow<Selection: Hashable, Content: View>: View {
    let title: LocalizedStringKey
    @Binding var selection: Selection
    let options: [Selection]
    var accessibilityIdentifier: String?
    let optionLabel: (Selection) -> Content
    var footer: LocalizedStringKey?
    var footerForegroundStyle: Color = .secondary
    var onSelectionChange: ((Selection) -> Void)?

    init(
        _ title: LocalizedStringKey,
        selection: Binding<Selection>,
        options: [Selection],
        accessibilityIdentifier: String? = nil,
        footer: LocalizedStringKey? = nil,
        footerForegroundStyle: Color = .secondary,
        onSelectionChange: ((Selection) -> Void)? = nil,
        @ViewBuilder optionLabel: @escaping (Selection) -> Content
    ) {
        self.title = title
        self._selection = selection
        self.options = options
        self.accessibilityIdentifier = accessibilityIdentifier
        self.optionLabel = optionLabel
        self.footer = footer
        self.footerForegroundStyle = footerForegroundStyle
        self.onSelectionChange = onSelectionChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker(title, selection: Binding(
                get: { selection },
                set: { newValue in
                    selection = newValue
                    onSelectionChange?(newValue)
                }
            )) {
                ForEach(options, id: \.self, content: optionLabel)
            }
            .applyAccessibilityIdentifier(accessibilityIdentifier)

            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(footerForegroundStyle)
            }
        }
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
