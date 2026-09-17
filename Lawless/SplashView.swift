//
//  SplashView.swift
//  Lawless
//
//  Branded launch screen shown while the SwiftData store is seeded, and a
//  reusable typewriter text-reveal effect used here and in "Mentor".
//

import SwiftUI
import SwiftData

// MARK: - SplashContainerView

/// Hosts the splash screen, seeds the database, then hands off to `RootView`.
/// This is what `LawlessApp` should put inside its `WindowGroup`.
struct SplashContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showSplash = true

    var body: some View {
        ZStack {
            LawlessTheme.background.ignoresSafeArea()
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                RootView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showSplash)
        .task {
            DataImporter.shared.seedIfNeeded(context: modelContext)
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            showSplash = false
        }
    }
}

// MARK: - SplashView

struct SplashView: View {
    @State private var textRevealed = false

    var body: some View {
        ZStack {
            LawlessTheme.background.ignoresSafeArea()

            VStack(spacing: 22) {
                AppLogoHeaderView(size: 108)

                VStack(spacing: 8) {
                    Text("LAWLESS")
                        .font(LawlessTheme.display(32))
                        .foregroundStyle(LawlessTheme.textPrimary)
                        .neonGlow(LawlessTheme.neonCyan, radius: 6)
                        .opacity(textRevealed ? 1 : 0)
                        .animation(.easeOut(duration: 0.5), value: textRevealed)

                    TypewriterText(
                        text: "INITIALIZING PROTOCOL...",
                        font: LawlessTheme.mono(11, weight: .medium),
                        color: LawlessTheme.textSecondary,
                        charInterval: 0.03
                    )
                }
            }
        }
        .onAppear {
            textRevealed = true
        }
    }
}

// MARK: - TypewriterText

/// Reveals `text` one character at a time, like a terminal typing itself out.
/// Restarts automatically whenever `text` changes, so it's safe to reuse
/// inside a `ForEach` of log lines.
struct TypewriterText: View {
    let text: String
    var font: Font = LawlessTheme.mono(12)
    var color: Color = LawlessTheme.textPrimary
    var charInterval: Double = 0.018
    var onComplete: (() -> Void)? = nil

    @State private var visibleCount = 0
    @State private var runToken = UUID()

    var body: some View {
        Text(String(text.prefix(visibleCount)))
            .font(font)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear { start() }
            .onChange(of: text) { _, _ in start() }
    }

    private func start() {
        let token = UUID()
        runToken = token
        visibleCount = 0
        let characters = Array(text)

        Task { @MainActor in
            for i in 0...characters.count {
                guard runToken == token else { return }
                visibleCount = i
                if i < characters.count {
                    try? await Task.sleep(nanoseconds: UInt64(charInterval * 1_000_000_000))
                }
            }
            if runToken == token {
                onComplete?()
            }
        }
    }
}

#Preview {
    SplashView()
}
