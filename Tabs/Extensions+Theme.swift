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

    /// Contrast color for content placed ON a tabsPrimary-filled background.
    static let tabsOnPrimary = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.09, blue: 0.20, alpha: 1)
            : UIColor.white
    })

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
    static func tabsDisplay(_ size: CGFloat = 48) -> Font {
        .custom("Georgia", size: size)
    }
    static func tabsTitle(_ size: CGFloat = 28) -> Font {
        .custom("Georgia", size: size)
    }
    static func tabsBody(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func tabsMono(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }
}

// MARK: - Corner Radius

extension CGFloat {
    static let tabsCardRadius: CGFloat   = 24
    static let tabsSheetRadius: CGFloat  = 28
    static let tabsButtonRadius: CGFloat = 16
    static let tabsPillRadius: CGFloat   = 100
}

// MARK: - Liquid Glass Spring System
//
// All animations in Tabs use one of four named spring presets so the
// physics feel is consistent throughout the app.

extension Animation {
    /// Snappy — toggles, small state pops, icon swaps.
    static let tabsSnap   = Animation.spring(response: 0.26, dampingFraction: 0.70)
    /// Standard — card reveals, list insertions, badge changes.
    static let tabsSpring = Animation.spring(response: 0.36, dampingFraction: 0.76)
    /// Fluid — large section transitions, sheet content.
    static let tabsFluid  = Animation.spring(response: 0.46, dampingFraction: 0.80)
    /// Bounce — liquid-glass scale pops, FAB, spotlight entry.
    static let tabsBounce = Animation.spring(response: 0.40, dampingFraction: 0.60)
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
            .background(
                color
                    .opacity(configuration.isPressed ? 0.80 : 1)
                    .animation(.tabsSnap, value: configuration.isPressed)
            )
            .cornerRadius(.tabsPillRadius)
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .animation(.tabsSnap, value: configuration.isPressed)
    }
}

struct TabsSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.tabsBody(16, weight: .semibold))
            .foregroundColor(.tabsPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                Color.tabsCard
                    .opacity(configuration.isPressed ? 0.75 : 1)
                    .animation(.tabsSnap, value: configuration.isPressed)
            )
            .cornerRadius(.tabsPillRadius)
            .overlay(
                RoundedRectangle(cornerRadius: .tabsPillRadius)
                    .strokeBorder(Color.tabsPrimary.opacity(0.15), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .animation(.tabsSnap, value: configuration.isPressed)
    }
}

/// Springy scale-down style for card-like tappable items.
/// On press: scales down + slight brightness drop for a glass-press feel.
struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.965
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? -0.018 : 0)
            .animation(.tabsSnap, value: configuration.isPressed)
    }
}

extension View {
    func tabsCard(padding: CGFloat = 20) -> some View {
        modifier(TabsCardStyle(padding: padding))
    }
}

// MARK: - Currency Formatter
// Formatters are expensive to allocate — cache them as static instances
// so each computed property call doesn't pay the allocation cost.

private enum TabsFormatters {
    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle    = .currency
        f.currencySymbol = "$"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()

    // DateFormatter is expensive to allocate — one static instance is
    // shared across the entire app to avoid per-call allocation overhead.
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}

extension Double {
    var currencyString: String {
        let str = TabsFormatters.currency.string(from: NSNumber(value: abs(self))) ?? "$0"
        return self < 0 ? "-\(str)" : str
    }

    var signedCurrencyString: String {
        let str = TabsFormatters.currency.string(from: NSNumber(value: abs(self))) ?? "$0"
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
    var shortDisplay: String { TabsFormatters.shortDate.string(from: self) }
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
        .buttonStyle(ScaleButtonStyle(scale: 0.90))
    }
}

// MARK: - Loading Overlay
// Uses a blur material instead of a solid black scrim for a liquid-glass look.

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 4)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                    .scaleEffect(1.3)
            }
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
                .foregroundColor(.tabsPrimary)
                .tint(.tabsPrimary)
        }
        .animation(.tabsSnap, value: text.isEmpty)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.tabsCard)
        .cornerRadius(.tabsButtonRadius)
    }
}

// MARK: - Liquid Glass Toggle
// A custom on/off toggle with a fluid spring animation on the thumb and a
// subtle glass highlight strip on the track — liquid-glass design.

struct LiquidGlassToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.tabsBounce) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                // Track background
                Capsule()
                    .fill(isOn ? Color.tabsGreen : Color.tabsCardSecondary)
                    .frame(width: 51, height: 31)
                    .animation(.tabsSnap, value: isOn)

                // Glass sheen on the track
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.20), Color.clear],
                            startPoint: .topLeading, endPoint: .center
                        )
                    )
                    .frame(width: 51, height: 31)
                    .allowsHitTesting(false)

                // Thumb with glass highlight
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.white, Color.white.opacity(0.90)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 27, height: 27)
                    .shadow(color: Color.black.opacity(0.20), radius: 4, y: 2)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.55), Color.clear],
                                    startPoint: .topLeading, endPoint: .center
                                )
                            )
                            .padding(3)
                    )
                    .padding(.horizontal, 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Currency Field

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
                .foregroundColor(.tabsPrimary)
                .tint(.tabsPrimary)
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
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, text.isEmpty ? 0 : 6)
        .animation(.tabsSnap, value: text.isEmpty)
    }
}
