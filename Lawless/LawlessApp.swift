//
//  LawlessApp.swift
//  Lawless
//
//  App entry point. Configures the SwiftData ModelContainer, shows the
//  branded splash screen, then hosts the root tab-based navigation shell.
//

import SwiftUI
import SwiftData

@main
struct LawlessApp: App {

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorkspaceTask.self,
            Transaction.self,
            HabitEntry.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("[Lawless] Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Force the whole app into dark mode regardless of system setting —
        // this is a pure-black HUD, it never goes light.
        UITabBar.appearance().barTintColor = UIColor(LawlessTheme.background)
    }

    var body: some Scene {
        WindowGroup {
            SplashContainerView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - RootView

/// Root tab shell — "Protocol" / "Vault" / "Mentor" — styled as a black HUD
/// with a neon-cyan active state.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .protocol_

    enum Tab {
        case protocol_
        case vault
        case mentor
    }

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(LawlessTheme.background)
        appearance.shadowColor = UIColor(LawlessTheme.border)

        let normalAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(LawlessTheme.textSecondary),
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        ]
        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(LawlessTheme.neonCyan),
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .bold)
        ]

        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(LawlessTheme.textSecondary)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(LawlessTheme.neonCyan)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            WeeklyTrackerView()
                .tabItem {
                    Label("Protocol", systemImage: "bolt.fill")
                }
                .tag(Tab.protocol_)

            FinanceTrackerView()
                .tabItem {
                    Label("Vault", systemImage: "lock.shield.fill")
                }
                .tag(Tab.vault)

            MentorView()
                .tabItem {
                    Label("Mentor", systemImage: "terminal.fill")
                }
                .tag(Tab.mentor)
        }
        .tint(LawlessTheme.neonCyan)
        .task {
            // Idempotent — safe even though SplashContainerView already seeds
            // on first launch (e.g. when RootView is used directly in a preview).
            DataImporter.shared.seedIfNeeded(context: modelContext)
        }
    }
}
