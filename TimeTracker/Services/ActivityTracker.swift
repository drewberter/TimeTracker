//
//  ActivityTracker.swift
//  TimeTracker
//
//  Created by Drew on 2/25/25.
//

import Cocoa
import CoreData
import UserNotifications

class ActivityTracker {
	static let shared = ActivityTracker()
	private var currentActivity: ActivityRecord?
	private var startTime: Date?
	private(set) var isTracking = true
	
	private init() {
		UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
			if let error = error {
				print("Error requesting notification authorization: \(error)")
			}
		}
	}
	
	func checkCurrentActivity() {
		guard isTracking else { return }
		
		// Use optional binding for NSWorkspace.shared.frontmostApplication
		if let app = NSWorkspace.shared.frontmostApplication {
			let appName = app.localizedName ?? "Unknown"
			
			if let window = getCurrentWindow() {
				// Check if we already have an ongoing activity with the same details
				if let currentActivity = self.currentActivity,
				   currentActivity.application == appName,
				   currentActivity.title == window.title {
					
					// Update duration for current activity
					if let start = startTime {
						currentActivity.duration = Date().timeIntervalSince(start)
						
						// Save the context without ending the activity
						do {
							try PersistenceController.shared.container.viewContext.save()
						} catch {
							print("Error updating duration: \(error)")
						}
					}
					
					return
				}
				
				// Create new activity record
				let context = PersistenceController.shared.container.viewContext
				let newActivity = ActivityRecord(context: context)
				newActivity.application = appName
				newActivity.title = window.title
				newActivity.path = window.path
				newActivity.timestamp = Date()
				newActivity.duration = 0
				
				// Try to match project using the ProjectMatcher
				if let projectNumber = ProjectMatcher.shared.guessProject(title: window.title, path: window.path) {
					newActivity.projectNumber = projectNumber
					promptForProjectConfirmation(projectNumber, activity: newActivity)
				}
				
				updateActivity(newActivity)
			}
		}
	}
	
	private func getCurrentWindow() -> (title: String, path: String)? {
		let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
		let windowListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] ?? []
		
		for window in windowListInfo {
			// Fix optional binding
			if let owner = window[kCGWindowOwnerName as String] as? String,
			   let title = window[kCGWindowName as String] as? String,
			   let frontApp = NSWorkspace.shared.frontmostApplication,
			   owner == frontApp.localizedName {
				return (title: title, path: "")
			}
		}
		
		return nil
	}
	
	private func updateActivity(_ newActivity: ActivityRecord) {
		// Check if activity has changed
		if currentActivity?.title != newActivity.title ||
			currentActivity?.application != newActivity.application {
			
			// Record duration for previous activity
			if let start = startTime, let currentActivity = self.currentActivity {
				let duration = Date().timeIntervalSince(start)
				currentActivity.duration = duration
				
				// Only save if duration is significant (more than 5 seconds)
				if duration > 5 {
					// Save the context
					do {
						try PersistenceController.shared.container.viewContext.save()
					} catch {
						print("Error saving context: \(error)")
					}
				} else {
					// Delete too short activities
					PersistenceController.shared.container.viewContext.delete(currentActivity)
				}
			}
			
			// Start tracking new activity
			self.currentActivity = newActivity
			self.startTime = Date()
			
			// Save the new activity
			do {
				try PersistenceController.shared.container.viewContext.save()
			} catch {
				print("Error saving new activity: \(error)")
			}
		}
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
		} else if isTracking {
			// If resuming tracking, reset the start time for the current activity
			startTime = Date()
		}
	}
}
