//
//  TimeTrackerApp.swift
//  TimeTracker
//
//  Created by Drew on 2/18/25.
//

import SwiftUI

@main
struct TimeTrackerApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	let persistenceController = PersistenceController.shared

	var body: some Scene {
		WindowGroup {
			ContentView()
				.environment(\.managedObjectContext, persistenceController.container.viewContext)
		}
		.commands {
			// Add any menu commands here if needed
			CommandGroup(replacing: .newItem) { }  // Removes the default "New" menu item
		}
	}
}
