//
//  AnalyticsView.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/24/26.
//
//  Personal analytics across ALL tables the user is enrolled in.
//

import SwiftUI
import Charts

// A single session entry paired with its table name — used in history list.
struct SessionHistoryItem: Identifiable {
    var id: String { entry.id }
    let tableName: String
    let entry: SessionEntry
}

// MARK: - Analytics Summary
//
// All expensive aggregations are computed once when stats load and stored
// here.  Previously every computed property on AnalyticsView re-ran on
// every SwiftUI render pass (including chart redraws and mode toggles),
// doing redundant flatMap/sort/reduce work proportional to all entries.

struct AnalyticsSummary {
    let allEntries: [SessionEntry]
    let totalEarnings: Double
    let totalSessions: Int
    let bestSession: Double
    let winRate: Double
    let sessionHistoryItems: [SessionHistoryItem]
    let cumulativeData: [(index: Int, value: Double)]
    let perSessionData: [(index: Int, value: Double)]

    init(stats: [TableAnalyticsStat]) {
        let sorted = stats.flatMap { $0.entries }.sorted { $0.submittedAt < $1.submittedAt }
        allEntries    = sorted
        totalEarnings = stats.reduce(0) { $0 + $1.totalEarnings }
        totalSessions = stats.reduce(0) { $0 + $1.sessionCount }
        bestSession   = sorted.map { $0.netAmount }.max() ?? 0
        let wins      = sorted.filter { $0.netAmount > 0 }.count
        winRate       = sorted.isEmpty ? 0 : Double(wins) / Double(sorted.count)

        sessionHistoryItems = stats.flatMap { stat in
            stat.entries.map { SessionHistoryItem(tableName: stat.table.name, entry: $0) }
        }.sorted { $0.entry.submittedAt > $1.entry.submittedAt }

        var running = 0.0
        cumulativeData = sorted.enumerated().map { (i, entry) in
            running += entry.netAmount
            return (index: i + 1, value: running)
        }
        perSessionData = sorted.enumerated().map { (i, e) in (index: i + 1, value: e.netAmount) }
    }

    static let empty = AnalyticsSummary(stats: [])
}

struct AnalyticsView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var stats: [TableAnalyticsStat] = []
    @State private var summary: AnalyticsSummary = .empty
    @State private var isLoading = true
    @State private var chartMode: ChartMode = .cumulative
    @State private var showSessionHistory = false

    enum ChartMode: String, CaseIterable {
        case cumulative = "Cumulative"
        case perSession = "Per Session"
        var icon: String { self == .cumulative ? "chart.xyaxis.line" : "chart.bar.fill" }
    }

    // ── Body ─────────────────────────────────────────────────────────────

    var body: some View {
        ZStack {
            Color.tabsBackground.ignoresSafeArea()

            if isLoading {
                ProgressView("Loading your stats…")
                    .foregroundColor(.tabsSecondary)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        heroCard
                        if !summary.allEntries.isEmpty {
                            chartSection
                        }
                        if !stats.isEmpty {
                            tableBreakdown
                        }
                        if summary.allEntries.isEmpty && !isLoading {
                            emptyState
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
        }
        .navigationTitle("My Analytics")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showSessionHistory) {
            SessionHistorySheet(items: summary.sessionHistoryItems)
        }
        .task {
            let loaded = await vm.fetchMyStatsAcrossAllTables()
            let s = AnalyticsSummary(stats: loaded)
            withAnimation(.tabsFluid) {
                stats   = loaded
                summary = s
                isLoading = false
            }
        }
    }

    // ── Hero Card ──────────────────────────────────────────────────────

    private var heroCard: some View {
        VStack(spacing: 20) {
            // Avatar + name
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.tabsPrimary.opacity(0.08))
                        .frame(width: 64, height: 64)
                    Text(String(vm.currentUser?.name.prefix(1) ?? "?"))
                        .font(.tabsDisplay(26))
                        .foregroundColor(.tabsPrimary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(vm.currentUser?.name ?? "")
                        .font(.tabsBody(18, weight: .semibold))
                        .foregroundColor(.tabsPrimary)
                    Text("Across \(stats.count) table\(stats.count == 1 ? "" : "s")")
                        .font(.tabsBody(13))
                        .foregroundColor(.tabsSecondary)
                }
                Spacer()
            }

            // Stats row — all values read from pre-computed summary
            HStack(spacing: 0) {
                AnalyticsStat(
                    label: "Net P&L",
                    value: summary.totalEarnings.signedCurrencyString,
                    color: summary.totalEarnings.earningsColor
                )
                Divider().frame(height: 40)
                // Tappable sessions stat — opens chronological history
                Button {
                    if summary.totalSessions > 0 { showSessionHistory = true }
                } label: {
                    AnalyticsStat(
                        label: "Sessions",
                        value: "\(summary.totalSessions)",
                        color: .tabsPrimary,
                        showChevron: summary.totalSessions > 0
                    )
                }
                .buttonStyle(.plain)
                Divider().frame(height: 40)
                AnalyticsStat(
                    label: "Win Rate",
                    value: summary.totalSessions > 0 ? "\(Int(summary.winRate * 100))%" : "--",
                    color: summary.winRate >= 0.5 ? .tabsGreen : .tabsRed
                )
                Divider().frame(height: 40)
                AnalyticsStat(
                    label: "Best",
                    value: summary.totalSessions > 0 ? summary.bestSession.signedCurrencyString : "--",
                    color: .tabsGreen
                )
            }
        }
        .tabsCard()
    }

    // ── Chart Section ──────────────────────────────────────────────────

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Performance")
                    .font(.tabsBody(16, weight: .semibold))
                    .foregroundColor(.tabsPrimary)
                Spacer()
                // Mode toggle
                HStack(spacing: 0) {
                    ForEach(ChartMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.tabsSnap) {
                                chartMode = mode
                            }
                        } label: {
                            Image(systemName: mode.icon)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(chartMode == mode ? .white : .tabsSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(chartMode == mode ? Color.tabsPrimary : Color.clear)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(3)
                .background(Color.tabsCardSecondary)
                .cornerRadius(13)
            }

            Group {
                if chartMode == .cumulative {
                    cumulativeChart
                } else {
                    sessionBarsChart
                }
            }
            .frame(height: 200)
            .animation(.tabsSnap, value: chartMode)
        }
        .tabsCard()
    }

    private var cumulativeChart: some View {
        Chart(summary.cumulativeData, id: \.index) { point in
            LineMark(
                x: .value("Session", point.index),
                y: .value("P&L", point.value)
            )
            .foregroundStyle(
                point.value >= 0 ? Color.tabsGreen : Color.tabsRed
            )
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Session", point.index),
                yStart: .value("Zero", 0),
                yEnd: .value("P&L", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        (point.value >= 0 ? Color.tabsGreen : Color.tabsRed).opacity(0.18),
                        Color.clear
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .tabsChartStyle()
    }

    private var sessionBarsChart: some View {
        Chart(summary.perSessionData, id: \.index) { point in
            BarMark(
                x: .value("Session", point.index),
                y: .value("Net", point.value)
            )
            .foregroundStyle(point.value >= 0 ? Color.tabsGreen : Color.tabsRed)
            .cornerRadius(4)
        }
        .tabsChartStyle()
    }

    // ── Per-table Breakdown ────────────────────────────────────────────

    private var tableBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BY TABLE")
                .font(.tabsBody(11, weight: .semibold))
                .foregroundColor(.tabsSecondary)
                .tracking(1.5)

            LazyVStack(spacing: 8) {
                ForEach(stats) { stat in
                    TableStatRow(stat: stat)
                }
            }
        }
    }

    // ── Empty State ────────────────────────────────────────────────────

    private var emptyState: some View {
        EmptyStateView(
            icon: "chart.xyaxis.line",
            title: "No sessions yet",
            subtitle: "Complete a session to see your analytics here"
        )
    }
}

// MARK: - Analytics Stat Item

struct AnalyticsStat: View {
    let label: String
    let value: String
    let color: Color
    var showChevron: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Text(value)
                    .font(.tabsMono(15))
                    .foregroundColor(color)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.tabsSecondary.opacity(0.6))
                }
            }
            Text(label)
                .font(.tabsBody(11))
                .foregroundColor(.tabsSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Session History Sheet

struct SessionHistorySheet: View {
    let items: [SessionHistoryItem]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.tabsSecondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            HStack {
                Text("Session History")
                    .font(.tabsTitle(24))
                    .foregroundColor(.tabsPrimary)
                Spacer()
                DismissButton()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        SessionHistoryRow(item: item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Color.tabsBackground)
        .presentationCornerRadius(.tabsSheetRadius)
    }
}

// MARK: - Session History Row

struct SessionHistoryRow: View {
    let item: SessionHistoryItem

    var body: some View {
        HStack(spacing: 14) {
            // Net indicator dot
            ZStack {
                Circle()
                    .fill((item.entry.netAmount >= 0 ? Color.tabsGreen : Color.tabsRed).opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: item.entry.netAmount >= 0 ? "arrow.up" : "arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(item.entry.netAmount >= 0 ? .tabsGreen : .tabsRed)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.tableName)
                    .font(.tabsBody(14, weight: .semibold))
                    .foregroundColor(.tabsPrimary)
                Text(item.entry.submittedAt.shortDisplay)
                    .font(.tabsBody(12))
                    .foregroundColor(.tabsSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.entry.netAmount.signedCurrencyString)
                    .font(.tabsMono(15))
                    .foregroundColor(item.entry.netAmount.earningsColor)
                if !item.entry.isManualNet {
                    Text("in \(item.entry.buyIn.currencyString)")
                        .font(.tabsBody(11))
                        .foregroundColor(.tabsSecondary)
                }
            }
        }
        .padding(14)
        .background(Color.tabsCard)
        .cornerRadius(16)
    }
}

// MARK: - Table Stat Row

struct TableStatRow: View {
    let stat: TableAnalyticsStat

    var body: some View {
        HStack(spacing: 14) {
            // Table icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.tabsPrimary.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: "suit.club.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.tabsPrimary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(stat.table.name)
                    .font(.tabsBody(15, weight: .semibold))
                    .foregroundColor(.tabsPrimary)
                Text("\(stat.sessionCount) sessions · \(Int(stat.winRate * 100))% win rate")
                    .font(.tabsBody(12))
                    .foregroundColor(.tabsSecondary)
            }

            Spacer()

            Text(stat.totalEarnings.signedCurrencyString)
                .font(.tabsMono(15))
                .foregroundColor(stat.totalEarnings.earningsColor)
        }
        .padding(14)
        .background(Color.tabsCard)
        .cornerRadius(18)
    }
}

// MARK: - Chart Axis Style Helper

private extension View {
    func tabsChartStyle() -> some View {
        self
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine(stroke: StrokeStyle(dash: [4]))
                        .foregroundStyle(Color.tabsSecondary.opacity(0.2))
                    AxisValueLabel()
                        .font(.tabsBody(10))
                        .foregroundStyle(Color.tabsSecondary)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(dash: [4]))
                        .foregroundStyle(Color.tabsSecondary.opacity(0.2))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v.currencyString)
                                .font(.tabsBody(10))
                                .foregroundStyle(Color.tabsSecondary)
                        }
                    }
                }
            }
    }
}
