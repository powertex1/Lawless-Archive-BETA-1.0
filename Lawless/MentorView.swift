//
//  MentorView.swift
//  Lawless
//
//  Tab 3 — "Mentor AI 2.0": an interactive terminal-style diagnostics
//  readout. Types incoming log lines character-by-character, exposes
//  [RE-SCAN SYSTEM] / [OPTIMIZE SCHEDULE] / [GENERATE SUMMARY] actions, and
//  raises smart, budget- and completion-aware alerts from live SwiftData
//  state.
//

import SwiftUI
import SwiftData

// MARK: - Log Line Model

private enum LogLevel: Equatable {
    case info, ok, warn, critical

    var tag: String {
        switch self {
        case .info: return "INFO"
        case .ok: return "OK  "
        case .warn: return "WARN"
        case .critical: return "CRIT"
        }
    }

    var color: Color {
        switch self {
        case .info: return LawlessTheme.textSecondary
        case .ok: return LawlessTheme.neonCyan
        case .warn: return LawlessTheme.energyYellow
        case .critical: return LawlessTheme.dangerRed
        }
    }
}

private struct LogLine: Identifiable {
    let id = UUID()
    let level: LogLevel
    let message: String
}

// MARK: - MentorView

struct MentorView: View {
    @Query private var tasks: [WorkspaceTask]
    @Query private var transactions: [Transaction]
    @Query private var habits: [HabitEntry]
    @AppStorage(LawlessDefaultsKey.monthlyBudgetTarget) private var monthlyBudgetTarget: Double = 1800

    /// The log as currently rendered on screen (grows via re-scan / actions).
    @State private var displayedLines: [LogLine] = []
    /// Index of the line currently being typed out; -1 when idle.
    @State private var typingIndex: Int = -1
    @State private var isBusy = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                terminalHeader
                ScrollView {
                    ScrollViewReader { proxy in
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(displayedLines.enumerated()), id: \.element.id) { index, line in
                                logRow(line: line, isTyping: index == typingIndex)
                                    .id(index)
                            }
                            if isBusy {
                                cursorRow
                                    .id("cursor")
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onChange(of: typingIndex) { _, _ in
                            withAnimation {
                                if isBusy {
                                    proxy.scrollTo("cursor", anchor: .bottom)
                                } else if !displayedLines.isEmpty {
                                    proxy.scrollTo(displayedLines.count - 1, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                .background(Color.black)
                actionButtonsRow
            }
            .background(LawlessTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .onAppear {
            if displayedLines.isEmpty {
                runFullScan()
            }
        }
    }

    // MARK: Header

    private var terminalHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                AppLogoHeaderView(size: 28)
                Text("MENTOR")
                    .font(LawlessTheme.display(20))
                    .foregroundStyle(LawlessTheme.textPrimary)
                    .neonGlow(LawlessTheme.neonCyan, radius: 4)
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(LawlessTheme.dangerRed).frame(width: 8, height: 8)
                    Circle().fill(LawlessTheme.energyYellow).frame(width: 8, height: 8)
                    Circle().fill(LawlessTheme.successGreen).frame(width: 8, height: 8)
                }
            }
            SectionLabel(text: "ai_diagnostics.exe — v2.0")
        }
        .padding(16)
        .background(LawlessTheme.card)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(LawlessTheme.border), alignment: .bottom)
    }

    // MARK: Rows

    private func logRow(line: LogLine, isTyping: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("[\(line.level.tag)]")
                .font(LawlessTheme.mono(11, weight: .bold))
                .foregroundStyle(line.level.color)

            if isTyping {
                TypewriterText(
                    text: line.message,
                    font: LawlessTheme.mono(12),
                    color: LawlessTheme.textPrimary.opacity(0.9),
                    charInterval: 0.012,
                    onComplete: advanceTyping
                )
            } else {
                Text(line.message)
                    .font(LawlessTheme.mono(12))
                    .foregroundStyle(LawlessTheme.textPrimary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var cursorRow: some View {
        HStack(spacing: 8) {
            Text("[....]")
                .font(LawlessTheme.mono(11, weight: .bold))
                .foregroundStyle(LawlessTheme.textMuted)
            BlinkingCursor()
        }
    }

    // MARK: Action Buttons (Feature C: Interactive Terminal)

    private var actionButtonsRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                actionButton(title: "RE-SCAN SYSTEM", icon: "arrow.clockwise") { runFullScan() }
                actionButton(title: "OPTIMIZE SCHEDULE", icon: "wand.and.stars") { optimizeSchedule() }
            }
            actionButton(title: "GENERATE SUMMARY", icon: "doc.text.fill", fullWidth: true) { generateSummary() }
        }
        .padding(12)
        .background(LawlessTheme.card)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(LawlessTheme.border), alignment: .top)
    }

    private func actionButton(title: String, icon: String, fullWidth: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text("[\(title)]")
                    .font(LawlessTheme.mono(10, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .foregroundStyle(LawlessTheme.neonCyan)
            .background(LawlessTheme.cardElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(LawlessTheme.neonCyan.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .disabled(isBusy)
        .opacity(isBusy ? 0.5 : 1)
    }

    // MARK: Typing Engine

    private func advanceTyping() {
        if typingIndex < displayedLines.count - 1 {
            typingIndex += 1
        } else {
            isBusy = false
        }
    }

    private func appendLines(_ newLines: [LogLine]) {
        guard !newLines.isEmpty else { return }
        let wasIdle = !isBusy
        let insertionIndex = displayedLines.count
        displayedLines.append(contentsOf: newLines)
        isBusy = true
        if wasIdle {
            typingIndex = insertionIndex
        }
    }

    // MARK: Actions

    private func runFullScan() {
        displayedLines = diagnostics
        isBusy = true
        typingIndex = displayedLines.isEmpty ? -1 : 0
    }

    private func optimizeSchedule() {
        var lines: [LogLine] = [LogLine(level: .info, message: "Running schedule optimizer...")]

        let today = calendar.startOfDay(for: .now)
        let pendingHighEnergy = tasks.filter {
            calendar.isDate($0.date, inSameDayAs: today) && !$0.isCompleted && $0.energyLevel >= 4
        }

        if pendingHighEnergy.isEmpty {
            lines.append(LogLine(level: .ok, message: "No high-energy backlog. Schedule is already balanced."))
        } else {
            for task in pendingHighEnergy.prefix(3) {
                lines.append(LogLine(
                    level: .warn,
                    message: "Move '\(task.title)' to your next peak-focus window (energy \(task.energyLevel))."
                ))
            }
        }

        let strugglingHabits = Set(habits.map(\.habitName)).sorted().filter {
            currentHabitStreak(habitName: $0, entries: habits, calendar: calendar) == 0
        }
        if !strugglingHabits.isEmpty {
            lines.append(LogLine(
                level: .warn,
                message: "Re-anchor habit(s): \(strugglingHabits.joined(separator: ", ")). Pair with an existing routine."
            ))
        }

        lines.append(LogLine(level: .ok, message: "Optimization pass complete."))
        appendLines(lines)
    }

    private func generateSummary() {
        var lines: [LogLine] = [LogLine(level: .info, message: "Compiling summary report...")]

        let today = calendar.startOfDay(for: .now)
        let todaysTasks = tasks.filter { calendar.isDate($0.date, inSameDayAs: today) }
        let done = todaysTasks.filter(\.isCompleted).count
        lines.append(LogLine(level: .info, message: "Tasks: \(done)/\(todaysTasks.count) complete today."))

        let monthTx = transactions.filter { calendar.isDate($0.date, equalTo: .now, toGranularity: .month) }
        let expense = monthTx.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        lines.append(LogLine(
            level: .info,
            message: "Spend: €\(String(format: "%.2f", expense)) of €\(String(format: "%.0f", monthlyBudgetTarget)) budget."
        ))

        let habitNames = Set(habits.map(\.habitName)).sorted()
        let streaks = habitNames.map { (name: $0, streak: currentHabitStreak(habitName: $0, entries: habits, calendar: calendar)) }
        if let best = streaks.filter({ $0.streak > 0 }).max(by: { $0.streak < $1.streak }) {
            lines.append(LogLine(level: .ok, message: "Longest active streak: '\(best.name)' at \(best.streak) day(s)."))
        } else {
            lines.append(LogLine(level: .warn, message: "No active habit streaks right now."))
        }

        lines.append(LogLine(level: .info, message: "Summary generated. End of report."))
        appendLines(lines)
    }

    // MARK: Diagnostics Engine

    /// Parses the current SwiftData state into a list of pseudo-AI log lines.
    private var diagnostics: [LogLine] {
        var lines: [LogLine] = []

        lines.append(LogLine(level: .info, message: "Booting Lawless Mentor kernel v2.0..."))
        lines.append(LogLine(level: .info, message: "Connected to local vault. Parsing metrics..."))

        // --- Task metrics (Smart Advice: completion rate > 80%) ---
        let today = calendar.startOfDay(for: .now)
        let todaysTasks = tasks.filter { calendar.isDate($0.date, inSameDayAs: today) }
        let doneToday = todaysTasks.filter(\.isCompleted).count

        if todaysTasks.isEmpty {
            lines.append(LogLine(level: .warn, message: "No tasks registered for today. Protocol queue is empty."))
        } else {
            let ratio = Double(doneToday) / Double(todaysTasks.count)
            if ratio > 0.8 {
                lines.append(LogLine(level: .ok, message: "SYSTEM OPTIMAL: Efficiency at peak — \(Int(ratio * 100))% task completion."))
            } else if ratio >= 0.4 {
                lines.append(LogLine(level: .info, message: "Task completion at \(Int(ratio * 100))% — on pace, no anomalies detected."))
            } else {
                lines.append(LogLine(level: .warn, message: "Task completion at \(Int(ratio * 100))% — falling behind protocol."))
            }
        }

        let highEnergyPending = todaysTasks.filter { !$0.isCompleted && $0.energyLevel >= 4 }
        if !highEnergyPending.isEmpty {
            lines.append(LogLine(
                level: .warn,
                message: "\(highEnergyPending.count) high-energy task(s) still pending. Run OPTIMIZE SCHEDULE for a rebalance plan."
            ))
        }

        // --- Habit metrics ---
        let habitNames = Set(habits.map(\.habitName))
        for name in habitNames.sorted() {
            let streak = currentHabitStreak(habitName: name, entries: habits, calendar: calendar)
            if streak >= 5 {
                lines.append(LogLine(level: .ok, message: "Habit '\(name)' streak: \(streak) days. Reinforcement pattern locked in."))
            } else if streak == 0 {
                lines.append(LogLine(level: .warn, message: "Habit '\(name)' streak broken. Integrity check recommended."))
            }
        }

        // --- Financial metrics (Smart Advice: over-budget alert) ---
        let monthTx = transactions.filter { calendar.isDate($0.date, equalTo: .now, toGranularity: .month) }
        let income = monthTx.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        let expense = monthTx.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }

        if monthlyBudgetTarget > 0 {
            let budgetRatio = expense / monthlyBudgetTarget
            if expense > monthlyBudgetTarget {
                lines.append(LogLine(
                    level: .critical,
                    message: "CRITICAL ALERT: Over-budget detected — €\(String(format: "%.2f", expense)) spent of €\(String(format: "%.0f", monthlyBudgetTarget)) target."
                ))
            } else if budgetRatio >= 0.85 {
                lines.append(LogLine(level: .warn, message: "Budget at \(Int(budgetRatio * 100))% — approaching monthly limit."))
            } else {
                lines.append(LogLine(level: .ok, message: "Budget at \(Int(budgetRatio * 100))% — vault is stable."))
            }
        }

        if income > 0 && expense > income {
            lines.append(LogLine(level: .critical, message: "Expenses exceed income this cycle. Net negative trajectory."))
        }

        let grouped = Dictionary(grouping: monthTx.filter { !$0.isIncome }, by: \.category)
        if let topCategory = grouped.max(by: { a, b in
            a.value.reduce(0) { $0 + $1.amount } < b.value.reduce(0) { $0 + $1.amount }
        }) {
            let total = topCategory.value.reduce(0) { $0 + $1.amount }
            lines.append(LogLine(level: .info, message: "Top spend category: '\(topCategory.key)' at €\(String(format: "%.2f", total))."))
        }

        let flagCount = lines.filter { $0.level == .warn || $0.level == .critical }.count
        lines.append(LogLine(level: .info, message: "Diagnostic scan complete. \(flagCount) flag(s) raised."))

        return lines
    }
}

// MARK: - Blinking Cursor

private struct BlinkingCursor: View {
    @State private var visible = true

    var body: some View {
        Rectangle()
            .fill(LawlessTheme.neonCyan)
            .frame(width: 8, height: 14)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    visible.toggle()
                }
            }
    }
}

#Preview {
    MentorView()
        .modelContainer(for: [WorkspaceTask.self, Transaction.self, HabitEntry.self], inMemory: true)
        .preferredColorScheme(.dark)
}
