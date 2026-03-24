//
//  PlayerDetailView.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/22/26.
//
//  Requires Swift Charts (iOS 16+) — already included in the SDK.
//

import SwiftUI
import Charts

struct PlayerDetailView: View {
    let player: TablePlayer
    let table: PokerTable

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var history: [SessionEntry] = []
    @State private var isLoading = true
    @State private var chartMode: ChartMode = .line
    @State private var showLogEntry = false

    enum ChartMode: String, CaseIterable {
        case line = "Line"
        case bar  = "Bar"
        var icon: String { self == .line ? "chart.xyaxis.line" : "chart.bar.fill" }
    }

    private var isCurrentUser: Bool {
        player.userId == vm.currentUser?.id
    }

    // Cumulative data for line chart
    private var cumulativeData: [(index: Int, value: Double, date: Date)] {
        var running = 0.0
        return history.enumerated().map { (i, entry) in
            running += entry.netAmount
            return (index: i + 1, value: running, date: entry.submittedAt)
        }
    }

    // Per-session data for bar chart
    private var sessionData: [(index: Int, value: Double, date: Date)] {
        history.enumerated().map { (i, entry) in
            (index: i + 1, value: entry.netAmount, date: entry.submittedAt)
        }
    }

    var body: some View {
        ZStack {
            Color.tabsBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // Hero card
                    heroCard

                    // Chart section
                    if !history.isEmpty {
                        chartSection
                    }

                    // History list
                    historySection

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .navigationTitle(player.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isCurrentUser && table.hasActiveSession {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Log Entry") { showLogEntry = true }
                        .font(.tabsBody(14, weight: .semibold))
                        .foregroundColor(.tabsGreen)
                }
            }
        }
        .sheet(isPresented: $showLogEntry) {
            LogEntryView(table: table, player: player)
                .environmentObject(vm)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(.tabsSheetRadius)
        }
        .task {
            history = await vm.fetchPlayerHistory(playerId: player.id, tableId: table.id)
            isLoading = false
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.tabsPrimary.opacity(0.08))
                    .frame(width: 72, height: 72)
                Text(String(player.name.prefix(1)))
                    .font(.tabsDisplay(30))
                    .foregroundColor(.tabsPrimary)
            }

            Text(player.name)
                .font(.tabsTitle(24))
                .foregroundColor(.tabsPrimary)

            // Stats row
            HStack(spacing: 0) {
                StatItem(label: "Total", value: player.totalEarnings.signedCurrencyString,
                         color: player.totalEarnings.earningsColor)
                Divider().frame(height: 36)
                StatItem(label: "Sessions", value: "\(history.count)", color: .tabsPrimary)
                Divider().frame(height: 36)
                StatItem(label: "Best", value: bestSession, color: .tabsGreen)
            }
        }
        .tabsCard()
    }

    private var bestSession: String {
        history.map { $0.netAmount }.max().map { $0.signedCurrencyString } ?? "--"
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Performance")
                    .font(.tabsBody(16, weight: .semibold))
                    .foregroundColor(.tabsPrimary)
                Spacer()
                // Chart mode toggle
                HStack(spacing: 0) {
                    ForEach(ChartMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { chartMode = mode }
                        } label: {
                            Image(systemName: mode.icon)
                                .font(.system(size: 14, weight: .medium))
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

            // Chart
            Group {
                if chartMode == .line {
                    lineChart
                } else {
                    barChart
                }
            }
            .frame(height: 200)
        }
        .tabsCard()
    }

    private var lineChart: some View {
        Chart(cumulativeData, id: \.index) { point in
            LineMark(
                x: .value("Session", point.index),
                y: .value("Cumulative", point.value)
            )
            .foregroundStyle(Color.tabsPrimary)
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Session", point.index),
                yStart: .value("Zero", 0),
                yEnd: .value("Cumulative", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.tabsPrimary.opacity(0.15), Color.clear],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
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

    private var barChart: some View {
        Chart(sessionData, id: \.index) { point in
            BarMark(
                x: .value("Session", point.index),
                y: .value("Net", point.value)
            )
            .foregroundStyle(point.value >= 0 ? Color.tabsGreen : Color.tabsRed)
            .cornerRadius(4)
        }
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

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SESSION HISTORY")
                .font(.tabsBody(11, weight: .semibold))
                .foregroundColor(.tabsSecondary)
                .tracking(1.5)

            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }.padding()
            } else if history.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "No sessions yet",
                    subtitle: "Results will appear here once sessions are completed"
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(history.enumerated().reversed()), id: \.element.id) { idx, entry in
                        SessionEntryRow(entry: entry, sessionNumber: idx + 1)
                    }
                }
            }
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.tabsMono(17))
                .foregroundColor(color)
            Text(label)
                .font(.tabsBody(12))
                .foregroundColor(.tabsSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Session Entry Row

struct SessionEntryRow: View {
    let entry: SessionEntry
    let sessionNumber: Int

    var body: some View {
        HStack(spacing: 14) {
            // Session number
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.tabsPrimary.opacity(0.07))
                    .frame(width: 40, height: 40)
                Text("S\(sessionNumber)")
                    .font(.tabsBody(12, weight: .bold))
                    .foregroundColor(.tabsPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.submittedAt.shortDisplay)
                    .font(.tabsBody(14, weight: .semibold))
                    .foregroundColor(.tabsPrimary)
                if !entry.isManualNet {
                    Text("Buy-in: \(entry.buyIn.currencyString) · Out: \(entry.finalAmount.currencyString)")
                        .font(.tabsBody(12))
                        .foregroundColor(.tabsSecondary)
                } else {
                    Text("Manual net entry")
                        .font(.tabsBody(12))
                        .foregroundColor(.tabsSecondary)
                }
            }

            Spacer()

            Text(entry.netAmount.signedCurrencyString)
                .font(.tabsMono(16))
                .foregroundColor(entry.netAmount.earningsColor)
        }
        .padding(14)
        .background(Color.tabsCard)
        .cornerRadius(16)
    }
}
