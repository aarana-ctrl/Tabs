//
//  JoinCreateTableView.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/22/26.
//

import SwiftUI

// MARK: - Join Table

struct JoinTableView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var code: String = ""
    @State private var isLoading = false
    @State private var errorMsg: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Join a Table")
                        .font(.tabsTitle(28))
                        .foregroundColor(.tabsPrimary)
                    Text("Enter the 6-digit reference code")
                        .font(.tabsBody(14))
                        .foregroundColor(.tabsSecondary)
                }
                Spacer()
                DismissButton()
            }
            .padding(.top, 4)

            // Code input
            VStack(spacing: 6) {
                TextField("e.g. 482910", text: $code)
                    .font(.tabsMono(28))
                    .foregroundColor(.tabsPrimary)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .padding(.vertical, 20)
                    .background(Color.tabsCard)
                    .cornerRadius(.tabsButtonRadius)
                    .onChange(of: code) { _, new in
                        code = String(new.prefix(6))
                        errorMsg = nil
                    }

                if let err = errorMsg {
                    Text(err)
                        .font(.tabsBody(13))
                        .foregroundColor(.tabsRed)
                        .padding(.top, 2)
                }
            }

            Button {
                Task { await joinTable() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Join Table")
                    }
                }
            }
            .buttonStyle(TabsPrimaryButtonStyle())
            .disabled(code.count != 6 || isLoading)
            .opacity(code.count == 6 ? 1 : 0.45)

            Spacer()
        }
        .padding(24)
        .background(Color.tabsBackground)
    }

    private func joinTable() async {
        isLoading = true
        let result = await vm.joinTable(code: code)
        isLoading = false
        if result != nil {
            dismiss()
        } else {
            errorMsg = vm.errorMessage ?? "Could not join table."
            vm.errorMessage = nil
        }
    }
}

// MARK: - Create Table

struct CreateTableView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var tableName: String = ""
    @State private var isLoading = false
    @State private var createdTable: PokerTable? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create a Table")
                        .font(.tabsTitle(28))
                        .foregroundColor(.tabsPrimary)
                    Text("You'll be the admin of this table")
                        .font(.tabsBody(14))
                        .foregroundColor(.tabsSecondary)
                }
                Spacer()
                DismissButton()
            }
            .padding(.top, 4)

            if let table = createdTable {
                // Success state — show code
                successView(table: table)
            } else {
                VStack(spacing: 14) {
                    FloatingTextField(label: "Table name", text: $tableName)

                    Button {
                        Task { await createTable() }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Create Table")
                            }
                        }
                    }
                    .buttonStyle(TabsPrimaryButtonStyle())
                    .disabled(tableName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    .opacity(tableName.isEmpty ? 0.45 : 1)
                }
            }

            Spacer()
        }
        .padding(24)
        .background(Color.tabsBackground)
    }

    private func successView(table: PokerTable) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.tabsGreen)
                Text("Table Created!")
                    .font(.tabsTitle(24))
                    .foregroundColor(.tabsPrimary)
                Text("Share this code so others can join:")
                    .font(.tabsBody(14))
                    .foregroundColor(.tabsSecondary)
            }

            // Reference code display
            HStack {
                Spacer()
                Text(table.referenceCode)
                    .font(.tabsMono(36))
                    .foregroundColor(.tabsPrimary)
                    .tracking(6)
                Spacer()
            }
            .padding(.vertical, 24)
            .background(Color.tabsCard)
            .cornerRadius(.tabsCardRadius)

            Button("Done") { dismiss() }
                .buttonStyle(TabsPrimaryButtonStyle())
        }
    }

    private func createTable() async {
        isLoading = true
        let result = await vm.createTable(name: tableName.trimmingCharacters(in: .whitespaces))
        isLoading = false
        if let table = result {
            withAnimation { createdTable = table }
        }
    }
}
