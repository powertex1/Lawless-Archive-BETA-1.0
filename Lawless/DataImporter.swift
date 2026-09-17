//
//  DataImporter.swift
//  Lawless
//
//  Singleton responsible for auto-seeding the SwiftData store the first time
//  the app runs, so "Protocol", "Vault", and "Mentor" all have real data to
//  render without requiring manual setup.
//

import Foundation
import SwiftData

final class DataImporter {

    static let shared = DataImporter()
    private init() {}

    /// Entry point — call once, e.g. from `.task` on the app's root view.
    /// Each seeding step independently no-ops if data already exists,
    /// so this is safe to call on every launch.
    func seedIfNeeded(context: ModelContext) {
        seedTasksIfNeeded(context: context)
        seedHabitsIfNeeded(context: context)
        seedTransactionsIfNeeded(context: context)

        do {
            try context.save()
        } catch {
            print("[DataImporter] Failed to save seed data: \(error)")
        }
    }

    // MARK: - Tasks

    private func seedTasksIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<WorkspaceTask>()
        guard let count = try? context.fetchCount(descriptor), count == 0 else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        // Default daily protocol — mirrors a real focus/ops checklist.
        let todayTasks: [(String, Bool, Int)] = [
            ("Проверить email", true, 2),
            ("Позвонить клиенту", true, 3),
            ("Подготовить отчет", true, 3),
            ("4 часа фокуса", false, 5),
            ("Спортивная тренировка", false, 4),
            ("Проверить финансы", false, 2)
        ]

        let tomorrowTasks: [(String, Bool, Int)] = [
            ("Запланировать неделю", false, 2),
            ("Купить продукты", false, 2),
            ("Обновить CRM", false, 3),
            ("Созвон с заказчиком", false, 3)
        ]

        for (title, done, energy) in todayTasks {
            context.insert(WorkspaceTask(date: today, title: title, isCompleted: done, energyLevel: energy))
        }

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) {
            for (title, done, energy) in tomorrowTasks {
                context.insert(WorkspaceTask(date: tomorrow, title: title, isCompleted: done, energyLevel: energy))
            }
        }
    }

    // MARK: - Habits

    private func seedHabitsIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<HabitEntry>()
        guard let count = try? context.fetchCount(descriptor), count == 0 else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        // Core habit set, matching a real recurring-habit tracker.
        let habitNames = [
            "💻 кодинг",
            "🏋️ зал",
            "📖 10 страниц книги",
            "🇺🇸 английский",
            "🧘 медитация",
            "💰 бизнес",
            "🥗 правильное питание",
            "🎤 репчик"
        ]

        // Seed the last 7 days with a semi-realistic, non-uniform completion
        // pattern so the Mentor tab has streaks/warnings to reason about.
        let completionSeed: [[Bool]] = [
            [true, true, true, false, true, true, false],
            [true, true, true, true, false, true, true],
            [true, true, true, true, true, true, true],
            [false, true, true, true, true, false, true],
            [true, true, false, true, true, true, true],
            [true, false, true, true, true, true, false],
            [false, true, true, false, true, true, true]
        ]

        for (habitIndex, name) in habitNames.enumerated() {
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                let completed = completionSeed[habitIndex % completionSeed.count][dayOffset % 7]
                context.insert(HabitEntry(habitName: name, date: date, isCompleted: completed))
            }
        }
    }

    // MARK: - Transactions

    private func seedTransactionsIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Transaction>()
        guard let count = try? context.fetchCount(descriptor), count == 0 else { return }

        let calendar = Calendar.current
        let now = Date.now

        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: now) ?? now
        }

        // Recurring monthly expenses (rent, subscriptions, transport, etc.)
        let expenses: [(String, Double, Int, String?)] = [
            ("Аренда жилья", 550, -14, nil),
            ("Мобильная связь", 15, -13, nil),
            ("Страхование", 330, -9, nil),
            ("Автомобиль", 450, -3, "Плановое ТО"),
            ("Кредиты", 150, -6, nil),
            ("Еда", 86.40, -1, "Продукты на неделю"),
            ("Кафе & Рестораны", 24.50, -2, nil),
            ("Подписки", 30, -5, "Стриминг + облако"),
            ("Одежда", 59.90, -4, nil)
        ]

        // Recurring income
        let income: [(String, Double, Int, String?)] = [
            ("Зарплата", 2300, -11, nil),
            ("Фриланс", 57, -8, "Верстка лендинга"),
            ("Инвестиции & Вклады", 124, -6, "Дивиденды"),
            ("Возврат долга", 1280, -3, nil)
        ]

        for (category, amount, offset, note) in expenses {
            context.insert(Transaction(date: day(offset), category: category, amount: amount, isIncome: false, note: note))
        }

        for (category, amount, offset, note) in income {
            context.insert(Transaction(date: day(offset), category: category, amount: amount, isIncome: true, note: note))
        }
    }
}
