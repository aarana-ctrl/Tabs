//
//  HomeView.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/22/26.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showAddOptions = false
    @State private var showJoinTable = false
    @State private var showCreateTable = false
    @State private var showSettings = false
    @State private var showAnalytics = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:       return "Good evening"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.tabsBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(greeting)
                                    .font(.tabsBody(15))
                                    .foregroundColor(.tabsSecondary)
                                Text(vm.currentUser?.name.components(separatedBy: " ").first ?? "Hey")
                                    .font(.tabsDisplay(44))
                                    .foregroundColor(.tabsPrimary)
                            }
                            Spacer()
                            // Avatar — taps to open Settings
                            Button {
                                showSettings = true
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.tabsPrimary)
                                        .frame(width: 44, height: 44)
                                    Text(String(vm.currentUser?.name.prefix(1) ?? "?"))
                                        .font(.tabsBody(18, weight: .semibold))
                                        .foregroundColor(.tabsOnPrimary)
                                }
                            }
                            .buttonStyle(ScaleButtonStyle(scale: 0.92))
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 28)

                        // Analytics strip
                        analyticsStrip
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)

                        // Tables section
                        if vm.isLoadingTables {
                            HStack { Spacer(); ProgressView(); Spacer() }
                                .padding(.top, 60)
                        } else if vm.tables.isEmpty {
                            emptyState
                                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                        } else {
                            tablesList
                                .transition(.opacity)
                        }

                        Spacer(minLength: 100)
                    }
                }

                // FAB menu items — sibling of the FAB button so they are
                // completely outside the Button's view hierarchy.  When they
                // were in the Button's .overlay, SwiftUI's button interaction
                // system propagated its default circular press highlight into
                // the child FabMenuItem buttons, causing the dark ghost circles.
                if showAddOptions {
                    fabMenu
                        .padding(.trailing, 20)
                        .padding(.bottom, 96)
                        .transition(.asymmetric(
                            insertion: .push(from: .bottom).combined(with: .opacity),
                            removal:   .push(from: .top).combined(with: .opacity)
                        ))
                }

                // Floating action button (circle only — no overlay)
                fabButton
            }
            .navigationBarHidden(true)
            .navigationDestination(for: PokerTable.self) { table in
                TableDetailView(table: table)
            }
            .navigationDestination(isPresented: $showAnalytics) {
                AnalyticsView()
                    .environmentObject(vm)
            }
            // Single load on appear — .task is lifecycle-aware and cancels on
            // disappear, so it replaces the old .onAppear { Task { ... } }.
            .task { await vm.loadTables() }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(vm)
                .presentationDetents([.large])
                .presentationCornerRadius(.tabsSheetRadius)
                .preferredColorScheme(vm.isDarkMode ? .dark : .light)
        }
        .sheet(isPresented: $showJoinTable) {
            JoinTableView()
                .environmentObject(vm)
                .presentationDetents([.medium])
                .presentationCornerRadius(.tabsSheetRadius)
        }
        .sheet(isPresented: $showCreateTable) {
            CreateTableView()
                .environmentObject(vm)
                .presentationDetents([.medium])
                .presentationCornerRadius(.tabsSheetRadius)
        }
        .refreshable { await vm.loadTables() }
        .animation(.tabsSpring, value: vm.isLoadingTables)
        .animation(.tabsSpring, value: vm.tables.isEmpty)
    }

    // MARK: - Analytics Strip

    private var analyticsStrip: some View {
        Button {
            showAnalytics = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.tabsGreen.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.tabsGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("My Analytics")
                        .font(.tabsBody(15, weight: .semibold))
                        .foregroundColor(.tabsPrimary)
                    Text("Net P&L, win rate & history across all tables")
                        .font(.tabsBody(12))
                        .foregroundColor(.tabsSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.tabsSecondary.opacity(0.5))
            }
            .padding(16)
            .background(Color.tabsCard)
            .cornerRadius(.tabsCardRadius)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Tables List

    private var tablesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR TABLES")
                .font(.tabsBody(11, weight: .semibold))
                .foregroundColor(.tabsSecondary)
                .tracking(1.5)
                .padding(.horizontal, 24)

            LazyVStack(spacing: 10) {
                ForEach(vm.tables) { table in
                    NavigationLink(value: table) {
                        TableRowCard(table: table)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, 16)
                    .transition(.asymmetric(
                        insertion: .push(from: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .animation(.tabsSpring, value: vm.tables.count)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 60)
            ZStack {
                RoundedRectangle(cornerRadius: .tabsCardRadius, style: .continuous)
                    .fill(Color.tabsCard)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .padding(.horizontal, 16)

                VStack(spacing: 16) {
                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 44, weight: .thin))
                        .foregroundColor(.tabsSecondary.opacity(0.6))
                    Text("Add your\ntables and games")
                        .font(.tabsTitle(26))
                        .foregroundColor(.tabsSecondary.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
            }

            Text("Create or join a table\nusing the + button below")
                .font(.tabsBody(14))
                .foregroundColor(.tabsSecondary)
                .multilineTextAlignment(.center)
                .italic()
        }
    }

    // MARK: - FAB

    private var fabButton: some View {
        Button {
            withAnimation(.tabsBounce) { showAddOptions.toggle() }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.tabsGreen)
                    .frame(width: 58, height: 58)
                    .shadow(color: Color.tabsGreen.opacity(showAddOptions ? 0.5 : 0.35),
                            radius: showAddOptions ? 16 : 12, x: 0, y: 4)
                    .animation(.tabsSnap, value: showAddOptions)

                Image(systemName: showAddOptions ? "xmark" : "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(showAddOptions ? 45 : 0))
                    .scaleEffect(showAddOptions ? 0.85 : 1)
                    .animation(.tabsBounce, value: showAddOptions)
            }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.92))
        .padding(.trailing, 20)
        .padding(.bottom, 28)
    }

    private var fabMenu: some View {
        VStack(alignment: .trailing, spacing: 10) {
            FabMenuItem(icon: "person.badge.plus", label: "Join Table") {
                withAnimation(.tabsBounce) { showAddOptions = false }
                showJoinTable = true
            }
            FabMenuItem(icon: "plus.rectangle.on.rectangle", label: "Create Table") {
                withAnimation(.tabsBounce) { showAddOptions = false }
                showCreateTable = true
            }
        }
    }
}

// MARK: - Table Row Card

struct TableRowCard: View {
    let table: PokerTable
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.tabsPrimary)
                    .frame(width: 48, height: 48)
                Image(systemName: "suit.club.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.tabsOnPrimary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(table.name)
                    .font(.tabsBody(16, weight: .semibold))
                    .foregroundColor(.tabsPrimary)
                HStack(spacing: 6) {
                    Text("\(table.memberIds.count) players")
                        .font(.tabsBody(13))
                        .foregroundColor(.tabsSecondary)
                    if table.hasActiveSession {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.tabsGreen)
                                .frame(width: 6, height: 6)
                            Text("Live")
                                .font(.tabsBody(12, weight: .medium))
                                .foregroundColor(.tabsGreen)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .animation(.tabsSnap, value: table.hasActiveSession)

            Spacer()

            if table.disputedAmount > 0 {
                VStack(spacing: 2) {
                    Text("Disputed")
                        .font(.tabsBody(10, weight: .medium))
                        .foregroundColor(.tabsRed)
                    Text(table.disputedAmount.currencyString)
                        .font(.tabsMono(12))
                        .foregroundColor(.tabsRed)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.tabsRed.opacity(0.1))
                .cornerRadius(10)
                .transition(.scale.combined(with: .opacity))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.tabsSecondary.opacity(0.5))
        }
        .padding(16)
        .background(Color.tabsCard)
        .cornerRadius(.tabsCardRadius)
    }
}

// MARK: - FAB Menu Item

struct FabMenuItem: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.tabsPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    // .regularMaterial gives frosted-glass contrast in both light and
                    // dark mode — Color.tabsCard was nearly invisible against the dark
                    // background, creating the "ghost circle" artifact.
                    .background(.regularMaterial,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)

                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.tabsGreen)
                        .frame(width: 48, height: 48)
                        .shadow(color: Color.tabsGreen.opacity(0.38), radius: 8, x: 0, y: 3)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.95))
    }
}
