//
//  AppLogoHeaderView.swift
//  Lawless
//
//  Reusable brand mark used in the splash screen and every tab's top header.
//  Loads the "AppLogo" asset if present; otherwise falls back to a
//  vector-drawn cyberpunk polygon/glitch glyph so the app never ships with a
//  missing image. Both paths get a pulsing neon-cyan backlight.
//

import SwiftUI
import Foundation

struct AppLogoHeaderView: View {
    /// Overall frame size (logo + glow both scale from this).
    var size: CGFloat = 32
    /// Whether to animate the pulsing backlight glow.
    var animateGlow: Bool = true

    @State private var pulse = false

    /// Cached once — avoids re-checking the asset catalog on every body evaluation.
    private static let hasCustomLogoAsset: Bool = UIImage(named: "AppLogo") != nil

    var body: some View {
        ZStack {
            // Pulsing neon backlight
            Circle()
                .fill(LawlessTheme.neonCyan)
                .frame(width: size * 1.9, height: size * 1.9)
                .blur(radius: size * 0.45)
                .opacity(pulse ? 0.55 : 0.22)
                .scaleEffect(pulse ? 1.08 : 0.92)
                .animation(
                    animateGlow
                        ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
                        : .default,
                    value: pulse
                )

            logoContent
                .frame(width: size, height: size)
        }
        .frame(width: size * 1.9, height: size * 1.9)
        .onAppear {
            guard animateGlow else { return }
            pulse = true
        }
    }

    @ViewBuilder
    private var logoContent: some View {
        if Self.hasCustomLogoAsset {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .neonGlow(LawlessTheme.neonCyan, radius: 3)
        } else {
            HUDLogoGlyph()
        }
    }
}

// MARK: - Fallback Vector HUD Logo

/// A cyberpunk-styled polygon/glitch mark, drawn purely in SwiftUI. Used
/// whenever no "AppLogo" image asset has been added to the project yet.
struct HUDLogoGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.24, style: .continuous)
                    .fill(LawlessTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: s * 0.24, style: .continuous)
                            .stroke(LawlessTheme.border, lineWidth: 1)
                    )

                // Outer polygon frame
                PolygonShape(sides: 6)
                    .stroke(LawlessTheme.neonCyan, lineWidth: max(1.4, s * 0.045))
                    .frame(width: s * 0.72, height: s * 0.72)

                // Offset "glitch" duplicate stroke
                PolygonShape(sides: 6)
                    .stroke(LawlessTheme.energyYellow.opacity(0.55), lineWidth: max(1, s * 0.028))
                    .frame(width: s * 0.72, height: s * 0.72)
                    .offset(x: s * 0.05, y: -s * 0.035)

                Image(systemName: "bolt.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: s * 0.32, height: s * 0.32)
                    .foregroundStyle(LawlessTheme.textPrimary)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// A regular N-sided polygon inscribed in `rect`, pointing up.
struct PolygonShape: Shape {
    var sides: Int

    func path(in rect: CGRect) -> Path {
        guard sides >= 3 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()

        for i in 0..<sides {
            let angle = (Double(i) / Double(sides)) * 2 * .pi - .pi / 2
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        LawlessTheme.background.ignoresSafeArea()
        VStack(spacing: 30) {
            AppLogoHeaderView(size: 32)
            AppLogoHeaderView(size: 110)
        }
    }
}
