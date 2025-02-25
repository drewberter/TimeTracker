import Cocoa
import CoreData
import UserNotifications

class ActivityTracker {
	static let shared = ActivityTracker()
	private var currentActivity: ActivityRecord?
	private var startTime: Date?
	private var isTracking = true
	
	private init() {
		// Request notification authorization when tracker is initialized
		UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
			if let error = error {
				print("Error requesting notification authorization: \(error)")
			}
		}
	}
	
	func checkCurrentActivity() {
		guard isTracking else { return }
		
		// Get current active application
		if let app = NSWorkspace.shared.frontmostApplication {
			let appName = app.localizedName ?? "Unknown"
			
			// Get active window information
			if let window = getCurrentWindow() {
				// Create new activity record
				let context = PersistenceController.shared.container.viewContext
				let newActivity = ActivityRecord(context: context)
				newActivity.application = appName
				newActivity.title = window.title
				newActivity.path = window.path
				newActivity.timestamp = Date()
				
				updateActivity(newActivity)
			}
		}
	}
	
	private func getCurrentWindow() -> (title: String, path: String)? {
		let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
		let windowListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] ?? []
		
		for window in windowListInfo {
			if let owner = window[kCGWindowOwnerName as String] as? String,
			   let title = window[kCGWindowName as String] as? String,
			   owner == NSWorkspace.shared.frontmostApplication?.localizedName {
				return (title: title, path: "")  // Path will be added with more detailed tracking
			}
		}
		
		return nil
	}
	
	private func updateActivity(_ newActivity: ActivityRecord) {
		// Check if activity has changed
		if currentActivity?.title != newActivity.title ||
			currentActivity?.application != newActivity.application {
			
			// Record duration for previous activity
			if let start = startTime {
				currentActivity?.duration = Date().timeIntervalSince(start)
				
				// Save the context
				do {
					try PersistenceController.shared.container.viewContext.save()
				} catch {
					print("Error saving context: \(error)")
				}
			}
			
			// Start tracking new activity
			currentActivity = newActivity
			startTime = Date()
			
			// Try to match project
			if let projectNumber = guessProject(for: newActivity) {
				promptForProjectConfirmation(projectNumber, activity: newActivity)
			}
		}
	}
	
	private func guessProject(for activity: ActivityRecord) -> String? {
		// Simple pattern matching for BMS project numbers
		let pattern = "BMS\\s*\\d{4}"
		if let title = activity.title,
		   let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
		   let match = regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)) {
			let matchedString = String(title[Range(match.range, in: title)!])
			return matchedString.replacingOccurrences(of: " ", with: "")
		}
		return nil
	}
	
	private func promptForProjectConfirmation(_ projectNumber: String, activity: ActivityRecord) {
		let content = UNMutableNotificationContent()
		content.title = "Project Match Found"
		content.subtitle = "Activity appears to be for project: \(projectNumber)"
		content.body = activity.title ?? ""
		
		// Store the activity ID for reference
		content.userInfo = ["activityID": activity.objectID.uriRepresentation().absoluteString]
		
		// Add custom actions
		content.categoryIdentifier = "PROJECT_CONFIRMATION"
		
		// Create and add the notification request
		let request = UNNotificationRequest(
			identifier: UUID().uuidString,
			content: content,
			trigger: nil
		)
		
		// Configure notification category with actions if not already done
		let confirmAction = UNNotificationAction(
			identifier: "CONFIRM_PROJECT",
			title: "Yes",
			options: .foreground
		)
		let category = UNNotificationCategory(
			identifier: "PROJECT_CONFIRMATION",
			actions: [confirmAction],
			intentIdentifiers: [],
			options: []
		)
		UNUserNotificationCenter.current().setNotificationCategories([category])
		
		// Add the notification request
		UNUserNotificationCenter.current().add(request) { error in
			if let error = error {
				print("Error showing notification: \(error)")
			}
		}
	}
	
	func toggleTracking() {
		isTracking.toggle()
		
		// If stopping tracking, save current activity duration
		if !isTracking, let currentActivity = currentActivity, let startTime = startTime {
			currentActivity.duration = Date().timeIntervalSince(startTime)
			do {
				try PersistenceController.shared.container.viewContext.save()
			} catch {
				print("Error saving context when stopping tracking: \(error)")
			}
		}
	}
}
