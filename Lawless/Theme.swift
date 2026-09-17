//
//  Theme.swift
//  Lawless
//
//  Cyberpunk / Hacker HUD design system — colors, fonts, and shared modifiers.
//

import SwiftUI

// MARK: - Hex Color Support

extension Color {
    /// Creates a Color from a 6-digit hex string, e.g. "00F5FF".
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var rgbValue: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Lawless Theme

enum LawlessTheme {
    // Core palette
    static let background = Color(hex: "000000")
    static let card = Color(hex: "141414")
    static let cardElevated = Color(hex: "1C1C1C")
    static let border = Color(hex: "2B2B2B")

    // Accents
    static let neonCyan = Color(hex: "00F5FF")
    static let energyYellow = Color(hex: "FFE500")
    static let dangerRed = Color(hex: "FF2E63")
    static let successGreen = Color(hex: "39FF88")

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8A8A8A")
    static let textMuted = Color(hex: "4A4A4A")

    // Typography
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Persisted Settings Keys

/// Central place for `@AppStorage` keys so views never rely on magic strings.
enum LawlessDefaultsKey {
    static let monthlyBudgetTarget = "lawless.monthlyBudgetTarget"
}

// MARK: - Shared Modifiers

struct NeonGlow: ViewModifier {
    var color: Color
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.9), radius: radius)
            .shadow(color: color.opacity(0.4), radius: radius * 2)
    }
}

extension View {
    func neonGlow(_ color: Color = LawlessTheme.neonCyan, radius: CGFloat = 5) -> some View {
        modifier(NeonGlow(color: color, radius: radius))
    }
}

struct HUDCard: ViewModifier {
    var borderColor: Color = LawlessTheme.border
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .background(LawlessTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func hudCard(border: Color = LawlessTheme.border, radius: CGFloat = 14) -> some View {
        modifier(HUDCard(borderColor: border, cornerRadius: radius))
    }
}

/// A small bracketed section label, e.g. "[ PROTOCOL ]" — a recurring HUD motif.
struct SectionLabel: View {
    let text: String
    var color: Color = LawlessTheme.neonCyan

    var body: some View {
        HStack(spacing: 4) {
            Text("//")
                .foregroundStyle(LawlessTheme.textMuted)
            Text(text.uppercased())
                .foregroundStyle(color)
                .tracking(2)
        }
        .font(LawlessTheme.mono(12, weight: .semibold))
    }
}

/// Reusable pill-style filter chip — used by the Protocol energy filter and
/// the Vault category filter.
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var accent: Color = LawlessTheme.neonCyan
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(LawlessTheme.mono(11, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? LawlessTheme.background : LawlessTheme.textSecondary)
                .background(isSelected ? accent : LawlessTheme.card)
                .overlay(
                    Capsule().stroke(isSelected ? Color.clear : LawlessTheme.border, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Reusable horizontal progress gauge — used by the Vault budget gauge and
/// category spend bars.
struct ProgressGaugeBar: View {
    var progress: Double // 0...1 (values above 1 are clamped visually)
    var color: Color
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(LawlessTheme.border)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)))
            }
        }
        .frame(height: height)
    }
}
