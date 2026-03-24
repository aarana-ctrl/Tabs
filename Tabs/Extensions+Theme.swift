//
//  Extensions+Theme.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/22/26.
//

import SwiftUI
import UIKit

// MARK: - Color Theme
// All surface/text colors are adaptive — they switch automatically when
// .preferredColorScheme(.dark) is applied to the root view.

extension Color {

    // ── Backgrounds ─────────────────────────────────────────────────────────
    /// Main app background  (light: #EEEEEE  |  dark: #0E0E0E)
    static let tabsBackground = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.055, green: 0.055, blue: 0.055, alpha: 1)
            : UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
    })

    /// Card surface  (light: white  |  dark: #1C1C1E)
    static let tabsCard = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
            : UIColor.white
    })

    /// Secondary card / input background  (light: #F5F5F5  |  dark: #2C2C2E)
    static let tabsCardSecondary = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1)
            : UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1)
    })

    // ── Text ─────────────────────────────────────────────────────────────────
    /// Primary text  (light: deep navy  |  dark: near-white)
    static let tabsPrimary = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
            : UIColor(red: 0.09, green: 0.09, blue: 0.20, alpha: 1)
    })

    /// Secondary / muted text  (same gray works in both modes)
    static let tabsSecondary = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1)
            : UIColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 1)
    })

    // ── Accents (same in both modes) ─────────────────────────────────────────
    static let tabsGreen     = Color(red: 0.24, green: 0.75, blue: 0.44)
    static let tabsGreenDark = Color(red: 0.17, green: 0.60, blue: 0.34)
    static let tabsRed       = Color(red: 0.93, green: 0.26, blue: 0.26)

    // ── Chart ────────────────────────────────────────────────────────────────
    static let chartPositive = Color(red: 0.24, green: 0.75, blue: 0.44)
    static let chartNegative = Color(red: 0.93, green: 0.26, blue: 0.26)
    static let chartLine     = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
            : UIColor(red: 0.09, green: 0.09, blue: 0.20, alpha: 1)
    })
}

// MARK: - Typography

extension Font {
    // Large serif display (matches the "Hi" heading in the reference)
    static func tabsDisplay(_ size: CGFloat = 48) -> Font {
        .custom("Georgia", size: size)
    }
    static func tabsTitle(_ size: CGFloat = 28) -> Font {
        .custom("Georgia", size: size)
    }
    // Body / UI uses SF Pro (system font)
    static func tabsBody(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func tabsMono(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }
}

// MARK: - Corner Radius

extension CGFloat {
    static let tabsCardRadius: CGFloat  = 24
    static let tabsSheetRadius: CGFloat = 28
    static let tabsButtonRadius: CGFloat = 16
    static let tabsPillRadius: CGFloat  = 100
}

// MARK: - View Modifiers

struct TabsCardStyle: ViewModifier {
    var padding: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.tabsCard)
            .cornerRadius(.tabsCardRadius)
    }
}

struct TabsPrimaryButtonStyle: ButtonStyle {
    var color: Color = .tabsPrimary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.tabsBody(16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1))
            .cornerRadius(.tabsPillRadius)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct TabsSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.tabsBody(16, weight: .semibold))
            .foregroundColor(.tabsPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.tabsCard.opacity(configuration.isPressed ? 0.8 : 1))
            .cornerRadius(.tabsPillRadius)
            .overlay(
                RoundedRectangle(cornerRadius: .tabsPillRadius)
                    .strokeBorder(Color.tabsPrimary.opacity(0.15), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func tabsCard(padding: CGFloat = 20) -> some View {
        modifier(TabsCardStyle(padding: padding))
    }
}

// MARK: - Currency Formatter

extension Double {
    var currencyString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        let str = formatter.string(from: NSNumber(value: abs(self))) ?? "$0"
        return self < 0 ? "-\(str)" : str
    }

    var signedCurrencyString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        let str = formatter.string(from: NSNumber(value: abs(self))) ?? "$0"
        if self > 0 { return "+\(str)" }
        if self < 0 { return "-\(str)" }
        return str
    }

    var earningsColor: Color {
        if self > 0 { return .tabsGreen }
        if self < 0 { return .tabsRed }
        return .tabsSecondary
    }
}

// MARK: - Date Helpers

extension Date {
    var shortDisplay: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: self)
    }
}

// MARK: - Dismissable Sheet

struct DismissButton: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.tabsSecondary)
                .padding(10)
                .background(Color.tabsCardSecondary)
                .clipShape(Circle())
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .thin))
                .foregroundColor(.tabsSecondary)
            Text(title)
                .font(.tabsBody(18, weight: .semibold))
                .foregroundColor(.tabsPrimary)
            Text(subtitle)
                .font(.tabsBody(14))
                .foregroundColor(.tabsSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

// MARK: - Floating Label TextField
// Used by JoinCreateTableView; text color is explicitly dark so it's
// visible against the white card background in both light and dark mode.

struct FloatingTextField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !text.isEmpty {
                Text(label)
                    .font(.tabsBody(11, weight: .medium))
                    .foregroundColor(.tabsSecondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            TextField(text.isEmpty ? label : "", text: $text)
                .font(.tabsBody(16))
                .foregroundColor(.tabsPrimary)         // explicit dark color
                .tint(.tabsPrimary)                    // cursor color
        }
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.tabsCard)
        .cornerRadius(.tabsButtonRadius)
    }
}

// MARK: - Currency Field
// Explicit foreground + tint colors so typed digits are clearly visible.

struct CurrencyField: View {
    let label: String
    @Binding var text: String
    var allowNegative: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            Text("$")
                .font(.tabsMono(18))
                .foregroundColor(.tabsSecondary)
                .padding(.leading, 18)

            TextField("0", text: $text)
                .font(.tabsMono(20))
                .foregroundColor(.tabsPrimary)         // explicit dark color
                .tint(.tabsPrimary)                    // cursor color
                .keyboardType(allowNegative ? .numbersAndPunctuation : .decimalPad)
                .padding(.leading, 4)
                .padding(.vertical, 16)
                .padding(.trailing, 18)
        }
        .background(Color.tabsCard)
        .cornerRadius(.tabsButtonRadius)
        .overlay(alignment: .topLeading) {
            if !text.isEmpty {
                Text(label)
                    .font(.tabsBody(10, weight: .medium))
                    .foregroundColor(.tabsSecondary)
                    .padding(.horizontal, 18)
                    .offset(y: -9)
            }
        }
        .padding(.top, text.isEmpty ? 0 : 6)
        .animation(.easeInOut(duration: 0.12), value: text.isEmpty)
    }
}
