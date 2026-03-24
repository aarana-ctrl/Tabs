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
    @State private var selectedTable: PokerTable? = nil
    @State private var navigateToTable = false

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
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(Color.tabsPrimary)
                                    .frame(width: 44, height: 44)
                                Text(String(vm.currentUser?.name.prefix(1) ?? "?"))
                                    .font(.tabsBody(18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .onTapGesture {
                                vm.signOut()
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 28)

                        // Tables section
                        if vm.isLoadingTables {
                            HStack { Spacer(); ProgressView(); Spacer() }
                                .padding(.top, 60)
                        } else if vm.tables.isEmpty {
                            emptyState
                        } else {
                            tablesList
                        }

                        Spacer(minLength: 100)
                    }
                }

                // Floating action button
                fabButton
            }
            .navigationBarHidden(true)
            .navigationDestination(for: PokerTable.self) { table in
                TableDetailView(table: table)
            }
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
        .refreshable {
            await vm.loadTables()
        }
        .task {
            if vm.tables.isEmpty {
                await vm.loadTables()
            }
        }
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
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
            }
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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showAddOptions.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.tabsGreen)
                    .frame(width: 58, height: 58)
                    .shadow(color: Color.tabsGreen.opacity(0.35), radius: 12, x: 0, y: 4)
                Image(systemName: showAddOptions ? "xmark" : "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(showAddOptions ? 45 : 0))
                    .animation(.spring(response: 0.25), value: showAddOptions)
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 28)
        .overlay(alignment: .bottomTrailing) {
            if showAddOptions {
                fabMenu
                    .padding(.trailing, 20)
                    .padding(.bottom, 96)
            }
        }
    }

    private var fabMenu: some View {
        VStack(alignment: .trailing, spacing: 10) {
            FabMenuItem(icon: "person.badge.plus", label: "Join Table") {
                showAddOptions = false
                showJoinTable = true
            }
            FabMenuItem(icon: "plus.rectangle.on.rectangle", label: "Create Table") {
                showAddOptions = false
                showCreateTable = true
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Table Row Card

struct TableRowCard: View {
    let table: PokerTable
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        HStack(spacing: 16) {
            // Table icon
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.tabsPrimary)
                    .frame(width: 48, height: 48)
                Image(systemName: "suit.club.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
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
                    }
                }
            }

            Spacer()

            // Dispute badge if any
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
            HStack(spacing: 10) {
                // Label pill — explicit non-tinted colors so text is always visible
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.09, green: 0.09, blue: 0.20))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 2)

                // Icon circle
                ZStack {
                    Circle()
                        .fill(Color(red: 0.09, green: 0.09, blue: 0.20))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.white)
                }
            }
        }
        .buttonStyle(.plain)   // prevents SwiftUI tint from washing out the label
    }
}
