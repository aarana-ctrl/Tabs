//
//  TabsApp.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/22/26.
//

import SwiftUI
import CoreData

@main
struct TabsApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
