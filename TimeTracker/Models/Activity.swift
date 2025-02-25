// Activity.swift
// TimeTracker
//
// Created by Drew on 2/25/25.
//

// Activity.swift
// TimeTracker
//
// Created by Drew on 2/25/25.
//

import Foundation
import AppKit

struct Activity: Identifiable, Equatable {
	let id = UUID()
	let application: String
	let title: String
	let path: String
	var projectNumber: String?
	let startTime: Date
	
	static func getCurrentActivity() -> Activity? {
		guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
		let appName = app.localizedName ?? "Unknown"
		
		// Get active document information
		var windowTitle = "Unknown"
		let documentPath = ""
		
		// Fix the conditional binding for NSRunningApplication.current
		if let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
			for window in windows {
				guard let windowOwnerPID = window[kCGWindowOwnerPID as String] as? Int,
					  let frontApp = NSWorkspace.shared.frontmostApplication,
					  windowOwnerPID == frontApp.processIdentifier,
					  let windowName = window[kCGWindowName as String] as? String,
					  !windowName.isEmpty else {
					continue
				}
				
				windowTitle = windowName
				break
			}
		}
		
		// Create activity object with mutable properties
		var activity = Activity(
			application: appName,
			title: windowTitle,
			path: documentPath,
			projectNumber: nil,
			startTime: Date()
		)
		
		// Use the ProjectMatcher class to detect project numbers
		if let projectNum = ProjectMatcher.shared.guessProject(for: activity) {
			activity.projectNumber = projectNum
		}
		
		return activity
	}
}
