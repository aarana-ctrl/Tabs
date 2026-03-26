//
//  ContentView.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/22/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        Group {
            if vm.isLoggedIn {
                HomeView()
            } else {
                LoginView()
            }
        }
        .animation(.tabsFluid, value: vm.isLoggedIn)
        .preferredColorScheme(vm.isDarkMode ? .dark : .light)
    }
}
