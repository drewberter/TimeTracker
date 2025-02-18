//
//  TimeTrackerApp.swift
//  TimeTracker
//
//  Created by Drew on 2/18/25.
//

import SwiftUI

@main
struct TimeTrackerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
