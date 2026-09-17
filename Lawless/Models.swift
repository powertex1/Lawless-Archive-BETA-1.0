//
//  Models.swift
//  Lawless
//
//  SwiftData model layer for tasks, finances, and habits.
//

import Foundation
import SwiftData

// MARK: - WorkspaceTask

/// A single task tracked in the "Protocol" tab, with an energy cost/rating attached.
@Model
final class WorkspaceTask {
    @Attribute(.unique) var id: UUID
    var date: Date
    var title: String
    var isCompleted: Bool
    /// Energy rating, 1-5 (⚡).
    var energyLevel: Int

    init(
        id: UUID = UUID(),
        date: Date = .now,
        title: String,
        isCompleted: Bool = false,
        energyLevel: Int = 3
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.isCompleted = isCompleted
        self.energyLevel = min(max(energyLevel, 1), 5)
    }
}

// MARK: - Energy Band (Feature A: Energy Filter)

/// Buckets `WorkspaceTask.energyLevel` into the three filter chips shown at
/// the top of "Protocol": All / High Energy / Low Energy.
enum EnergyBand: String, CaseIterable, Identifiable {
    case all = "ALL"
    case high = "HIGH ⚡⚡⚡"
    case low = "LOW ⚡"

    var id: String { rawValue }

    /// Whether a task with the given energy level belongs to this band.
    func matches(_ energyLevel: Int) -> Bool {
        switch self {
        case .all: return true
        case .high: return energyLevel >= 4
        case .low: return energyLevel <= 2
        }
    }
}

// MARK: - Transaction

/// A single financial movement tracked in the "Vault" tab.
@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var date: Date
    var category: String
    var amount: Double
    var isIncome: Bool
    var note: String?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        category: String,
        amount: Double,
        isIncome: Bool,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.category = category
        self.amount = amount
        self.isIncome = isIncome
        self.note = note
    }

    /// Signed amount: positive for income, negative for expense.
    var signedAmount: Double {
        isIncome ? amount : -amount
    }
}

// MARK: - HabitEntry

/// A single day's completion record for a recurring habit.
@Model
final class HabitEntry {
    @Attribute(.unique) var id: UUID
    var habitName: String
    var date: Date
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        habitName: String,
        date: Date = .now,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.habitName = habitName
        self.date = date
        self.isCompleted = isCompleted
    }
}

// MARK: - Habit Streak Calculation (Feature A: Streak Counter)

/// Computes the current consecutive-day completion streak for a given habit,
/// counting backward from today. A missed, incomplete, or absent day breaks
/// the streak. Shared by "Protocol" (streak badges) and "Mentor" (diagnostics).
func currentHabitStreak(
    habitName: String,
    entries: [HabitEntry],
    calendar: Calendar = .current
) -> Int {
    let sameHabit = entries
        .filter { $0.habitName == habitName }
        .sorted { $0.date > $1.date }

    var streak = 0
    var cursor = calendar.startOfDay(for: .now)
    var index = 0

    while index < sameHabit.count {
        let entryDay = calendar.startOfDay(for: sameHabit[index].date)
        if entryDay == cursor {
            if sameHabit[index].isCompleted {
                streak += 1
                cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
                index += 1
            } else {
                break
            }
        } else if entryDay < cursor {
            // No entry logged for `cursor` at all — streak breaks.
            break
        } else {
            index += 1
        }
    }
    return streak
}

// MARK: - Categories

/// Shared category list used by the Vault entry form, grouped as in a typical
/// personal-finance tracker (payments / expenses / debts / income).
enum TransactionCategory {
    static let expenseCategories: [String] = [
        "Аренда жилья", "Мобильная связь", "Интернет", "Страхование",
        "Еда", "Одежда", "Семья", "Кафе & Рестораны", "Автомобиль",
        "Подписки", "Личное", "Кредиты", "Абонементы", "Образование", "Развлечения"
    ]

    static let incomeCategories: [String] = [
        "Зарплата", "Премия", "Фриланс", "Инвестиции & Вклады", "Перевод от третьих лиц"
    ]
}
