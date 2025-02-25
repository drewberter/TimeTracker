import Cocoa
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
	var statusBarItem: NSStatusItem!
	private var currentActivityItem: NSMenuItem!
	private var toggleTrackingItem: NSMenuItem!
	private var timer: Timer?
	
	func applicationDidFinishLaunching(_ notification: Notification) {
		// Setup menu bar item
		statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		if let button = statusBarItem.button {
			button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Time Tracker")
		}
		
		setupMenu()
		
		// Start tracking with a shorter interval for more accuracy (15 seconds)
		timer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
			ActivityTracker.shared.checkCurrentActivity()
			self?.updateCurrentActivityDisplay()
			self?.updateToggleTrackingMenuTitle()
		}
		
		// Setup notification handling
		let notificationCenter = UNUserNotificationCenter.current()
		notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
			if granted {
				notificationCenter.delegate = self
			}
			if let error = error {
				print("Error requesting notification authorization: \(error)")
			}
		}
		
		// Initial activity check
		ActivityTracker.shared.checkCurrentActivity()
		updateCurrentActivityDisplay()
	}
	
	func setupMenu() {
		let menu = NSMenu()
		
		// Current activity display
		currentActivityItem = NSMenuItem(title: "Currently Tracking: None", action: nil, keyEquivalent: "")
		menu.addItem(currentActivityItem)
		
		menu.addItem(NSMenuItem.separator())
		
		// Open main window
		menu.addItem(NSMenuItem(title: "Open Dashboard", action: #selector(openDashboard), keyEquivalent: "d"))
		
		// Add Billing Reports menu item
		menu.addItem(NSMenuItem(title: "Billing Reports", action: #selector(openReports), keyEquivalent: "r"))
		
		// Toggle tracking
		toggleTrackingItem = NSMenuItem(title: "Pause Tracking", action: #selector(toggleTracking), keyEquivalent: "p")
		menu.addItem(toggleTrackingItem)
		
		menu.addItem(NSMenuItem.separator())
		menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
		
		statusBarItem.menu = menu
	}
	
	private func updateCurrentActivityDisplay() {
		let context = PersistenceController.shared.container.viewContext
		let fetchRequest: NSFetchRequest<ActivityRecord> = ActivityRecord.fetchRequest()
		fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ActivityRecord.timestamp, ascending: false)]
		fetchRequest.fetchLimit = 1
		
		if let latestActivity = try? context.fetch(fetchRequest).first {
			let title = latestActivity.title ?? "Unknown"
			let app = latestActivity.application ?? "Unknown App"
			let duration = formatDuration(latestActivity.duration)
			
			currentActivityItem.title = "Currently Tracking: \(title) (\(app)) - \(duration)"
		} else {
			currentActivityItem.title = "Currently Tracking: None"
		}
	}
	
	private func updateToggleTrackingMenuTitle() {
		toggleTrackingItem.title = ActivityTracker.shared.isTracking ? "Pause Tracking" : "Resume Tracking"
	}
	
	private func formatDuration(_ duration: Double) -> String {
		let hours = Int(duration) / 3600
		let minutes = Int(duration) / 60 % 60
		if hours > 0 {
			return "\(hours)h \(minutes)m"
		}
		return "\(minutes)m"
	}
	
	@objc func openDashboard() {
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
			styleMask: [.titled, .closable, .miniaturizable, .resizable],
			backing: .buffered,
			defer: false
		)
		
		window.title = "Time Tracker Dashboard"
		window.contentView = NSHostingView(rootView: ContentView()
			.environment(\.managedObjectContext, PersistenceController.shared.container.viewContext))
		window.center()
		window.makeKeyAndOrderFront(nil)
	}
	
	@objc func openReports() {
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
			styleMask: [.titled, .closable, .miniaturizable, .resizable],
			backing: .buffered,
			defer: false
		)
		
		window.title = "Billing Reports"
		window.contentView = NSHostingView(rootView: BillingReportsView()
			.environment(\.managedObjectContext, PersistenceController.shared.container.viewContext))
		window.center()
		window.makeKeyAndOrderFront(nil)
	}
	
	@objc func toggleTracking() {
		ActivityTracker.shared.toggleTracking()
		updateToggleTrackingMenuTitle()
	}
	
	// Handle notification responses
	func userNotificationCenter(
		_ center: UNUserNotificationCenter,
		didReceive response: UNNotificationResponse,
		withCompletionHandler completionHandler: @escaping () -> Void
	) {
		guard
			let activityIDString = response.notification.request.content.userInfo["activityID"] as? String,
			let activityURL = URL(string: activityIDString),
			let objectID = PersistenceController.shared.container.persistentStoreCoordinator.managedObjectID(forURIRepresentation: activityURL),
			let activity = try? PersistenceController.shared.container.viewContext.existingObject(with: objectID) as? ActivityRecord
		else {
			completionHandler()
			return
		}
		
		if response.actionIdentifier == "CONFIRM_PROJECT" {
			let subtitle = response.notification.request.content.subtitle
			let projectNumber = subtitle.replacingOccurrences(
				of: "Activity appears to be for project: ",
				with: ""
			).trimmingCharacters(in: .whitespaces)
			
			activity.projectNumber = projectNumber
			
			// Update the recent projects list
			ProjectMatcher.shared.updateRecentProjects(projectNumber)
			
			try? PersistenceController.shared.container.viewContext.save()
		}
		
		completionHandler()
	}
	
	func applicationWillTerminate(_ notification: Notification) {
		// Make sure to save the final state of any active tracking
		ActivityTracker.shared.checkCurrentActivity()
		
		// Invalidate the timer
		timer?.invalidate()
	}
}
