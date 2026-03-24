//
//  TabsApp.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/22/26.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct TabsApp: App {

    init() {
        // 1. Configure Firebase (reads GoogleService-Info.plist)
        FirebaseApp.configure()

        // 2. Configure Google Sign-In with the OAuth client ID from Firebase
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppViewModel.shared)
                // 3. Handle the Google Sign-In URL callback
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
