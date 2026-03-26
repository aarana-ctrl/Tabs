//
//  SettingsView.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/22/26.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showSignOutConfirm = false

    var body: some View {
        ZStack {
            Color.tabsBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.tabsSecondary.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {

                        // Profile header
                        profileHeader

                        // Appearance section
                        settingsSection(title: "APPEARANCE") {
                            SettingsRow(
                                icon: "moon.fill",
                                iconColor: Color(red: 0.42, green: 0.34, blue: 0.80),
                                title: "Dark Mode"
                            ) {
                                LiquidGlassToggle(isOn: $vm.isDarkMode)
                            }
                        }

                        // Account section
                        settingsSection(title: "ACCOUNT") {
                            // The button wraps the entire row so any tap on the
                            // card — icon, title, chevron, or empty space — triggers
                            // sign-out. contentShape(Rectangle()) ensures the full
                            // rectangular area (including Spacer()) is hittable.
                            Button {
                                showSignOutConfirm = true
                            } label: {
                                SettingsRow(
                                    icon: "rectangle.portrait.and.arrow.right",
                                    iconColor: .tabsRed,
                                    title: "Sign Out"
                                ) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.tabsSecondary.opacity(0.5))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(ScaleButtonStyle(scale: 0.975))
                        }

                        // App info
                        VStack(spacing: 4) {
                            Text("Tabs")
                                .font(.tabsBody(13, weight: .semibold))
                                .foregroundColor(.tabsSecondary)
                            Text("Version 1.0")
                                .font(.tabsBody(12))
                                .foregroundColor(.tabsSecondary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .presentationCornerRadius(.tabsSheetRadius)
        .alert("Sign Out", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    vm.signOut()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.tabsPrimary)
                    .frame(width: 58, height: 58)
                Text(String(vm.currentUser?.name.prefix(1) ?? "?"))
                    .font(.tabsDisplay(24))
                    .foregroundColor(.tabsOnPrimary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(vm.currentUser?.name ?? "")
                    .font(.tabsBody(18, weight: .semibold))
                    .foregroundColor(.tabsPrimary)
                Text(vm.currentUser?.email ?? "")
                    .font(.tabsBody(13))
                    .foregroundColor(.tabsSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.tabsCard)
        .cornerRadius(.tabsCardRadius)
    }

    // MARK: - Section Builder

    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.tabsBody(11, weight: .semibold))
                .foregroundColor(.tabsSecondary)
                .tracking(1.4)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.tabsCard)
            .cornerRadius(.tabsCardRadius)
        }
    }
}

// MARK: - Settings Row

struct SettingsRow<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 14) {
            // Icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(iconColor)
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }

            Text(title)
                .font(.tabsBody(15))
                .foregroundColor(.tabsPrimary)

            Spacer()

            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        // Extend hit-testing across the entire row including Spacer
        .contentShape(Rectangle())
    }
}
