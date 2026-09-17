//
//  FinanceTrackerView.swift
//  Lawless
//
//  Tab 2 — "Vault": monthly balance overview, a budget target gauge,
//  income/expense entry form, tap-to-filter category breakdown, and a
//  color-coded transaction history.
//

import SwiftUI
import SwiftData

struct FinanceTrackerView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @AppStorage(LawlessDefaultsKey.monthlyBudgetTarget) private var monthlyBudgetTarget: Double = 1800

    @State private var showingAddSheet = false
    @State private var showingBudgetEditor = false
    @State private var budgetInputText = ""
    @State private var selectedCategory: String? = nil

    private let calendar = Calendar.current

    // MARK: Derived data

    private var monthTransactions: [Transaction] {
        allTransactions.filter {
            calendar.isDate($0.date, equalTo: .now, toGranularity: .month)
        }
    }

    private var totalIncome: Double {
        monthTransactions.filter(\.isIncome).reduce(0) { $0 + $1.amount }
    }

    private var totalExpense: Double {
        monthTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }

    private var netBalance: Double {
        totalIncome - totalExpense
    }

    private var budgetRatio: Double {
        guard monthlyBudgetTarget > 0 else { return 0 }
        return totalExpense / monthlyBudgetTarget
    }

    private var budgetIsCritical: Bool {
        budgetRatio >= 0.85
    }

    /// History list, respecting the active category filter (if any).
    private var filteredHistory: [Transaction] {
        guard let selectedCategory else { return monthTransactions }
        return monthTransactions.filter { $0.category == selectedCategory }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    overviewCard
                    budgetGaugeCard
                    categoryBreakdown
                    historySection
                }
                .padding(16)
            }
            .background(LawlessTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddSheet) {
                AddTransactionSheet()
            }
            .alert("Set Monthly Budget", isPresented: $showingBudgetEditor) {
                TextField("Amount (€)", text: $budgetInputText)
                    .keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let value = Double(budgetInputText.replacingOccurrences(of: ",", with: ".")), value > 0 {
                        monthlyBudgetTarget = value
                    }
                }
            } message: {
                Text("This limit powers the budget gauge and Mentor's over-budget alerts.")
            }
        }
        .tint(LawlessTheme.neonCyan)
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 12) {
            AppLogoHeaderView(size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("VAULT")
                    .font(LawlessTheme.display(20))
                    .foregroundStyle(LawlessTheme.textPrimary)
                    .neonGlow(LawlessTheme.neonCyan, radius: 4)
                SectionLabel(text: Date.now.formatted(.dateTime.month(.wide).year()))
            }
            Spacer()
            Button {
                showingAddSheet = true
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

    private var overviewCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("NET BALANCE")
                    .font(LawlessTheme.mono(11))
                    .foregroundStyle(LawlessTheme.textSecondary)
                Spacer()
            }
            Text(currency(netBalance))
                .font(LawlessTheme.display(34))
                .foregroundStyle(netBalance >= 0 ? LawlessTheme.neonCyan : LawlessTheme.dangerRed)
                .neonGlow(netBalance >= 0 ? LawlessTheme.neonCyan : LawlessTheme.dangerRed, radius: 5)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider().background(LawlessTheme.border)

            HStack(spacing: 12) {
                metricBlock(label: "INCOME", value: totalIncome, color: LawlessTheme.successGreen, icon: "arrow.down.circle.fill")
                metricBlock(label: "EXPENSE", value: totalExpense, color: LawlessTheme.dangerRed, icon: "arrow.up.circle.fill")
            }
        }
        .padding(16)
        .hudCard()
    }

    private func metricBlock(label: String, value: Double, color: Color, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(LawlessTheme.mono(10))
                    .foregroundStyle(LawlessTheme.textSecondary)
                Text(currency(value))
                    .font(LawlessTheme.mono(14, weight: .bold))
                    .foregroundStyle(color)
            }
            Spacer()
        }
        .padding(12)
        .background(LawlessTheme.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Budget Gauge (Feature B)

    private var budgetGaugeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "monthly budget", color: budgetIsCritical ? LawlessTheme.dangerRed : LawlessTheme.neonCyan)
                Spacer()
                Button {
                    budgetInputText = String(format: "%.0f", monthlyBudgetTarget)
                    showingBudgetEditor = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LawlessTheme.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(currency(totalExpense))
                        .font(LawlessTheme.mono(15, weight: .bold))
                        .foregroundStyle(budgetIsCritical ? LawlessTheme.dangerRed : LawlessTheme.neonCyan)
                    Text("of \(currency(monthlyBudgetTarget)) target")
                        .font(LawlessTheme.mono(11))
                        .foregroundStyle(LawlessTheme.textSecondary)
                    Spacer()
                    Text("\(Int(min(budgetRatio, 9.99) * 100))%")
                        .font(LawlessTheme.mono(12, weight: .bold))
                        .foregroundStyle(budgetIsCritical ? LawlessTheme.dangerRed : LawlessTheme.textSecondary)
                }

                ProgressGaugeBar(
                    progress: budgetRatio,
                    color: budgetIsCritical ? LawlessTheme.dangerRed : LawlessTheme.neonCyan,
                    height: 10
                )

                if budgetIsCritical {
                    Text("⚠ OVER 85% OF BUDGET — SPENDING FLAGGED")
                        .font(LawlessTheme.mono(9, weight: .semibold))
                        .foregroundStyle(LawlessTheme.dangerRed)
                }
            }
        }
        .padding(16)
        .hudCard(border: budgetIsCritical ? LawlessTheme.dangerRed.opacity(0.4) : LawlessTheme.border)
    }

    // MARK: Category Breakdown (Feature B: Category Filter)

    private var categoryBreakdown: some View {
        let grouped = Dictionary(grouping: monthTransactions.filter { !$0.isIncome }, by: \.category)
        let totals = grouped.mapValues { $0.reduce(0) { $0 + $1.amount } }
        let sorted = totals.sorted { $0.value > $1.value }.prefix(6)
        let maxValue = sorted.map(\.value).max() ?? 1

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "top spend categories", color: LawlessTheme.energyYellow)
                Spacer()
                if selectedCategory != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedCategory = nil }
                    } label: {
                        HStack(spacing: 3) {
                            Text("CLEAR FILTER")
                            Image(systemName: "xmark.circle.fill")
                        }
                        .font(LawlessTheme.mono(9, weight: .semibold))
                        .foregroundStyle(LawlessTheme.neonCyan)
                    }
                }
            }

            if sorted.isEmpty {
                Text("NO EXPENSES LOGGED THIS MONTH")
                    .font(LawlessTheme.mono(12))
                    .foregroundStyle(LawlessTheme.textMuted)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .hudCard()
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(sorted), id: \.key) { category, total in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedCategory = (selectedCategory == category) ? nil : category
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(category)
                                        .font(LawlessTheme.mono(12, weight: .medium))
                                        .foregroundStyle(LawlessTheme.textPrimary)
                                    Spacer()
                                    Text(currency(total))
                                        .font(LawlessTheme.mono(12, weight: .bold))
                                        .foregroundStyle(LawlessTheme.energyYellow)
                                }
                                ProgressGaugeBar(
                                    progress: total / maxValue,
                                    color: LawlessTheme.energyYellow,
                                    height: 6
                                )
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                        .hudCard(border: selectedCategory == category ? LawlessTheme.energyYellow.opacity(0.5) : LawlessTheme.border)
                    }
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: selectedCategory.map { "activity — \($0)" } ?? "recent activity")
                Spacer()
            }
            if filteredHistory.isEmpty {
                Text("NO TRANSACTIONS TO SHOW")
                    .font(LawlessTheme.mono(12))
                    .foregroundStyle(LawlessTheme.textMuted)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .hudCard()
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredHistory.prefix(30)) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
            }
        }
    }

    private func currency(_ value: Double) -> String {
        let sign = value < 0 ? "-" : ""
        return "\(sign)€\(String(format: "%.2f", abs(value)))"
    }
}

// MARK: - TransactionRow

private struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.isIncome ? "arrow.down.left" : "arrow.up.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(transaction.isIncome ? LawlessTheme.successGreen : LawlessTheme.dangerRed)
                .frame(width: 30, height: 30)
                .background((transaction.isIncome ? LawlessTheme.successGreen : LawlessTheme.dangerRed).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.category)
                    .font(LawlessTheme.mono(13, weight: .medium))
                    .foregroundStyle(LawlessTheme.textPrimary)
                Text(transaction.date.formatted(.dateTime.day().month(.abbreviated)) + (transaction.note.map { " · \($0)" } ?? ""))
                    .font(LawlessTheme.mono(10))
                    .foregroundStyle(LawlessTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text((transaction.isIncome ? "+" : "-") + "€" + String(format: "%.2f", transaction.amount))
                .font(LawlessTheme.mono(13, weight: .bold))
                .foregroundStyle(transaction.isIncome ? LawlessTheme.successGreen : LawlessTheme.dangerRed)
        }
        .padding(12)
        .hudCard()
    }
}

// MARK: - AddTransactionSheet

private struct AddTransactionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isIncome: Bool = false
    @State private var category: String = TransactionCategory.expenseCategories[0]
    @State private var amountText: String = ""
    @State private var note: String = ""
    @State private var date: Date = .now

    private var categories: [String] {
        isIncome ? TransactionCategory.incomeCategories : TransactionCategory.expenseCategories
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $isIncome) {
                        Text("Expense").tag(false)
                        Text("Income").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: isIncome) { _, newValue in
                        category = newValue ? TransactionCategory.incomeCategories[0] : TransactionCategory.expenseCategories[0]
                    }
                }
                .listRowBackground(LawlessTheme.card)

                Section {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Amount (€)", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(LawlessTheme.mono(14))
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note (optional)", text: $note)
                        .font(LawlessTheme.mono(14))
                }
                .listRowBackground(LawlessTheme.card)
            }
            .scrollContentBackground(.hidden)
            .background(LawlessTheme.background)
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(Double(amountText.replacingOccurrences(of: ",", with: ".")) == nil)
                }
            }
        }
        .tint(LawlessTheme.neonCyan)
    }

    private func save() {
        guard let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) else { return }
        let transaction = Transaction(
            date: date,
            category: category,
            amount: amount,
            isIncome: isIncome,
            note: note.isEmpty ? nil : note
        )
        modelContext.insert(transaction)
        dismiss()
    }
}

#Preview {
    FinanceTrackerView()
        .modelContainer(for: [WorkspaceTask.self, Transaction.self, HabitEntry.self], inMemory: true)
        .preferredColorScheme(.dark)
}
