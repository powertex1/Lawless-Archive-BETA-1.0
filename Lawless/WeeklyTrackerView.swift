//
//  WeeklyTrackerView.swift
//  Lawless
//
//  Tab 1 — "Protocol": daily/weekly task tracker with an energy monitor,
//  a dynamic completion ring, an energy filter, a habit matrix with streak
//  counters, and a Quick-Add bottom sheet.
//

import SwiftUI
import SwiftData

struct WeeklyTrackerView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WorkspaceTask.date) private var allTasks: [WorkspaceTask]
    @Query(sort: \HabitEntry.date, order: .reverse) private var allHabits: [HabitEntry]

    @State private var scope: Scope = .today
    @State private var energyFilter: EnergyBand = .all
    @State private var showingQuickAdd = false

    enum Scope: String, CaseIterable, Identifiable {
        case today = "TODAY"
        case week = "WEEK"
        var id: String { rawValue }
    }

    private let calendar = Calendar.current

    // MARK: Derived data

    private var scopedTasks: [WorkspaceTask] {
        let today = calendar.startOfDay(for: .now)
        switch scope {
        case .today:
            return allTasks.filter { calendar.isDate($0.date, inSameDayAs: today) }
        case .week:
            guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: today) else { return allTasks }
            return allTasks
                .filter { $0.date >= weekAgo }
                .sorted { $0.date > $1.date }
        }
    }

    /// Scope + energy filter combined — this is what's actually rendered.
    private var visibleTasks: [WorkspaceTask] {
        scopedTasks.filter { energyFilter.matches($0.energyLevel) }
    }

    private var completionRatio: Double {
        guard !scopedTasks.isEmpty else { return 0 }
        let done = scopedTasks.filter(\.isCompleted).count
        return Double(done) / Double(scopedTasks.count)
    }

    private var todaysHabits: [(name: String, entry: HabitEntry?, streak: Int)] {
        let today = calendar.startOfDay(for: .now)
        let names = Set(allHabits.map(\.habitName)).sorted()
        return names.map { name in
            let entry = allHabits.first { $0.habitName == name && calendar.isDate($0.date, inSameDayAs: today) }
            let streak = currentHabitStreak(habitName: name, entries: allHabits, calendar: calendar)
            return (name, entry, streak)
        }
    }

    private var averageEnergy: Double {
        let completed = scopedTasks.filter(\.isCompleted)
        guard !completed.isEmpty else { return 0 }
        return Double(completed.reduce(0) { $0 + $1.energyLevel }) / Double(completed.count)
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    progressRingCard
                    scopePicker
                    energyFilterRow
                    tasksSection
                    habitMatrixSection
                }
                .padding(16)
            }
            .background(LawlessTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showingQuickAdd) {
                QuickAddTaskSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .tint(LawlessTheme.neonCyan)
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 12) {
            AppLogoHeaderView(size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("LAWLESS")
                    .font(LawlessTheme.display(20))
                    .foregroundStyle(LawlessTheme.textPrimary)
                    .neonGlow(LawlessTheme.neonCyan, radius: 4)
                SectionLabel(text: "protocol.sys")
            }
            Spacer()
            Button {
                showingQuickAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(LawlessTheme.background)
                    .frame(width: 36, height: 36)
                    .background(LawlessTheme.neonCyan)
                    .clipShape(Circle())
            }
        }
    }

    private var progressRingCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(LawlessTheme.border, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: completionRatio)
                    .stroke(
                        LawlessTheme.neonCyan,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: completionRatio)
                    .neonGlow(LawlessTheme.neonCyan, radius: 4)
                VStack(spacing: 0) {
                    Text("\(Int(completionRatio * 100))%")
                        .font(LawlessTheme.mono(20, weight: .bold))
                        .foregroundStyle(LawlessTheme.textPrimary)
                    Text("DONE")
                        .font(LawlessTheme.mono(9, weight: .medium))
                        .foregroundStyle(LawlessTheme.textSecondary)
                }
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 10) {
                statRow(label: "TASKS", value: "\(scopedTasks.filter(\.isCompleted).count)/\(scopedTasks.count)")
                statRow(label: "AVG ENERGY", value: String(format: "%.1f", averageEnergy), accent: LawlessTheme.energyYellow)
                statRow(label: "STATUS", value: statusLabel)
            }
            Spacer()
        }
        .padding(16)
        .hudCard()
    }

    private var statusLabel: String {
        switch completionRatio {
        case 1.0: return "OPTIMAL"
        case 0.5...: return "STABLE"
        case 0.001..<0.5: return "DEGRADED"
        default: return "IDLE"
        }
    }

    private func statRow(label: String, value: String, accent: Color = LawlessTheme.neonCyan) -> some View {
        HStack {
            Text(label)
                .font(LawlessTheme.mono(11))
                .foregroundStyle(LawlessTheme.textSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(LawlessTheme.mono(13, weight: .bold))
                .foregroundStyle(accent)
        }
    }

    private var scopePicker: some View {
        HStack(spacing: 0) {
            ForEach(Scope.allCases) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { scope = option }
                } label: {
                    Text(option.rawValue)
                        .font(LawlessTheme.mono(12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(scope == option ? LawlessTheme.background : LawlessTheme.textSecondary)
                        .background(scope == option ? LawlessTheme.neonCyan : Color.clear)
                }
            }
        }
        .background(LawlessTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(LawlessTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var energyFilterRow: some View {
        HStack(spacing: 8) {
            ForEach(EnergyBand.allCases) { band in
                FilterChip(
                    label: band.rawValue,
                    isSelected: energyFilter == band,
                    accent: LawlessTheme.energyYellow
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) { energyFilter = band }
                }
            }
            Spacer()
        }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "task queue")
            if visibleTasks.isEmpty {
                emptyState(text: "NO TASKS MATCH THIS FILTER")
            } else {
                VStack(spacing: 8) {
                    ForEach(visibleTasks) { task in
                        TaskRow(task: task)
                    }
                }
            }
        }
    }

    private var habitMatrixSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "habit matrix", color: LawlessTheme.energyYellow)
            if todaysHabits.isEmpty {
                emptyState(text: "NO HABITS TRACKED")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                    ForEach(todaysHabits, id: \.name) { habit in
                        HabitChip(name: habit.name, entry: habit.entry, streak: habit.streak)
                    }
                }
            }
        }
    }

    private func emptyState(text: String) -> some View {
        Text(text)
            .font(LawlessTheme.mono(12))
            .foregroundStyle(LawlessTheme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .hudCard()
    }
}

// MARK: - TaskRow

private struct TaskRow: View {
    @Bindable var task: WorkspaceTask
    @State private var showEnergyPicker = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        task.isCompleted.toggle()
                    }
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundStyle(task.isCompleted ? LawlessTheme.neonCyan : LawlessTheme.textSecondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(LawlessTheme.mono(14, weight: .medium))
                        .foregroundStyle(task.isCompleted ? LawlessTheme.textSecondary : LawlessTheme.textPrimary)
                        .strikethrough(task.isCompleted, color: LawlessTheme.textSecondary)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showEnergyPicker.toggle() }
                } label: {
                    HStack(spacing: 2) {
                        Text("\(task.energyLevel)")
                            .font(LawlessTheme.mono(12, weight: .bold))
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(LawlessTheme.energyYellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(LawlessTheme.energyYellow.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if showEnergyPicker {
                EnergyPicker(level: $task.energyLevel)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .hudCard(border: task.isCompleted ? LawlessTheme.neonCyan.opacity(0.3) : LawlessTheme.border)
    }
}

private struct EnergyPicker: View {
    @Binding var level: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    level = value
                } label: {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(value <= level ? LawlessTheme.energyYellow : LawlessTheme.border)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("ENERGY COST")
                .font(LawlessTheme.mono(9))
                .foregroundStyle(LawlessTheme.textMuted)
        }
    }
}

// MARK: - HabitChip

private struct HabitChip: View {
    @Environment(\.modelContext) private var modelContext
    let name: String
    let entry: HabitEntry?
    let streak: Int

    private var isCompleted: Bool { entry?.isCompleted ?? false }

    var body: some View {
        Button {
            toggle()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isCompleted ? LawlessTheme.neonCyan : LawlessTheme.card)
                        .overlay(Circle().stroke(LawlessTheme.border, lineWidth: 1))
                        .frame(width: 10, height: 10)
                    Text(name)
                        .font(LawlessTheme.mono(12, weight: .medium))
                        .foregroundStyle(isCompleted ? LawlessTheme.textPrimary : LawlessTheme.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                if streak > 0 {
                    Text("🔥 \(streak)-Day Streak")
                        .font(LawlessTheme.mono(10, weight: .semibold))
                        .foregroundStyle(LawlessTheme.energyYellow)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hudCard(border: isCompleted ? LawlessTheme.neonCyan.opacity(0.4) : LawlessTheme.border)
        }
        .buttonStyle(.plain)
    }

    private func toggle() {
        let today = Calendar.current.startOfDay(for: .now)
        if let entry {
            entry.isCompleted.toggle()
        } else {
            let newEntry = HabitEntry(habitName: name, date: today, isCompleted: true)
            modelContext.insert(newEntry)
        }
    }
}

// MARK: - QuickAddTaskSheet (Feature A: Quick-Add Task Modal)

private struct TaskPreset: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let energy: Int
}

private struct QuickAddTaskSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var customTitle: String = ""
    @State private var customEnergy: Int = 3
    @State private var customDate: Date = .now

    private let presets: [TaskPreset] = [
        TaskPreset(icon: "envelope.fill", title: "Проверить email", energy: 2),
        TaskPreset(icon: "phone.fill", title: "Позвонить клиенту", energy: 3),
        TaskPreset(icon: "figure.strengthtraining.traditional", title: "Тренировка", energy: 4),
        TaskPreset(icon: "brain.head.profile", title: "4 часа фокуса", energy: 5),
        TaskPreset(icon: "cart.fill", title: "Купить продукты", energy: 2),
        TaskPreset(icon: "wind", title: "Медитация 10 мин", energy: 1)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "quick presets")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                            ForEach(presets) { preset in
                                Button {
                                    addPreset(preset)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: preset.icon)
                                            .foregroundStyle(LawlessTheme.neonCyan)
                                            .frame(width: 22)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(preset.title)
                                                .font(LawlessTheme.mono(12, weight: .medium))
                                                .foregroundStyle(LawlessTheme.textPrimary)
                                                .lineLimit(2)
                                            Text("\(preset.energy) ⚡")
                                                .font(LawlessTheme.mono(10))
                                                .foregroundStyle(LawlessTheme.textSecondary)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(12)
                                    .hudCard()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "custom task", color: LawlessTheme.energyYellow)
                        VStack(spacing: 12) {
                            TextField("Task title", text: $customTitle)
                                .font(LawlessTheme.mono(14))
                                .foregroundStyle(LawlessTheme.textPrimary)
                                .padding(12)
                                .background(LawlessTheme.cardElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            DatePicker("Date", selection: $customDate, displayedComponents: .date)
                                .font(LawlessTheme.mono(12))

                            HStack {
                                Text("Energy")
                                    .font(LawlessTheme.mono(12))
                                    .foregroundStyle(LawlessTheme.textSecondary)
                                Spacer()
                                EnergyPicker(level: $customEnergy)
                            }

                            Button {
                                addCustom()
                            } label: {
                                Text("ADD TASK")
                                    .font(LawlessTheme.mono(13, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundStyle(LawlessTheme.background)
                                    .background(LawlessTheme.neonCyan)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .disabled(customTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                            .opacity(customTitle.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                        }
                        .padding(14)
                        .hudCard()
                    }
                }
                .padding(16)
            }
            .background(LawlessTheme.background.ignoresSafeArea())
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .tint(LawlessTheme.neonCyan)
    }

    private func addPreset(_ preset: TaskPreset) {
        let task = WorkspaceTask(
            date: Calendar.current.startOfDay(for: .now),
            title: preset.title,
            isCompleted: false,
            energyLevel: preset.energy
        )
        modelContext.insert(task)
        dismiss()
    }

    private func addCustom() {
        let task = WorkspaceTask(
            date: Calendar.current.startOfDay(for: customDate),
            title: customTitle,
            isCompleted: false,
            energyLevel: customEnergy
        )
        modelContext.insert(task)
        dismiss()
    }
}

#Preview {
    WeeklyTrackerView()
        .modelContainer(for: [WorkspaceTask.self, Transaction.self, HabitEntry.self], inMemory: true)
        .preferredColorScheme(.dark)
}
