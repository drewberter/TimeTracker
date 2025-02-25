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
		var documentPath = ""
		
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
		
		// Try to detect project number from title or path
		if let projectNum = detectProjectNumber(from: windowTitle, path: documentPath) {
			activity.projectNumber = projectNum
		}
		
		return activity
	}
	
	private static func detectProjectNumber(from title: String, path: String) -> String? {
		// Common project number formats
		let patterns = [
			// Match "BMS 1234" or similar project codes
			"\\b(BMS|PJT|PRJ)\\s*[0-9]{4,}\\b",
			// Match project-1234 format
			"\\bproject[-_]?[0-9]{4,}\\b",
			// Match #1234 format
			"#[0-9]{4,}\\b"
		]
		
		let textToSearch = "\(title) \(path)"
		
		for pattern in patterns {
			if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
			   let match = regex.firstMatch(in: textToSearch, range: NSRange(textToSearch.startIndex..., in: textToSearch)) {
				
				if let range = Range(match.range, in: textToSearch) {
					return String(textToSearch[range])
				}
			}
		}
		
		// Try to extract project from folder path
		if !path.isEmpty {
			let url = URL(fileURLWithPath: path)
			let folders = url.pathComponents
			
			// Check if any folder name matches project naming convention
			for folder in folders {
				for pattern in patterns {
					if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
					   let match = regex.firstMatch(in: folder, range: NSRange(folder.startIndex..., in: folder)) {
						
						if let range = Range(match.range, in: folder) {
							return String(folder[range])
						}
					}
				}
			}
		}
		
		return nil
	}
}
