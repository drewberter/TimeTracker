import Foundation
import UserNotifications

class LocalStorage {
	static let shared = LocalStorage()
	private let fileManager = FileManager.default
	private let storageURL: URL
	
	private init() {
		// Set up local storage directory
		let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		storageURL = appSupport.appendingPathComponent("TimeTracker")
		
		try? fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true, attributes: nil)
		
		// Request notification authorization
		UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
			if let error = error {
				print("Error requesting notification authorization: \(error)")
			}
		}
	}
	
	func saveActivity(_ activity: Activity, duration: TimeInterval) {
		let today = Date()
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd"
		let fileName = dateFormatter.string(from: today) + ".json"
		let fileURL = storageURL.appendingPathComponent(fileName)
		
		// Load existing data for today
		var activities: [[String: Any]] = []
		if let data = try? Data(contentsOf: fileURL),
		   let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
			activities = json
		}
		
		// Add new activity
		let newActivity: [String: Any] = [
			"application": activity.application,
			"title": activity.title,
			"path": activity.path,
			"duration": duration,
			"timestamp": Date().timeIntervalSince1970
		]
		activities.append(newActivity)
		
		// Save updated data
		if let data = try? JSONSerialization.data(withJSONObject: activities, options: .prettyPrinted) {
			try? data.write(to: fileURL)
		}
		
		// Check storage size
		checkStorageSize()
	}
	
	private func checkStorageSize() {
		// Get all files in storage directory
		guard let contents = try? fileManager.contentsOfDirectory(at: storageURL, includingPropertiesForKeys: [.fileSizeKey]) else {
			return
		}
		
		// Calculate total size
		let totalSize = contents.reduce(0) { sum, url in
			guard let resources = try? url.resourceValues(forKeys: [.fileSizeKey]),
				  let fileSize = resources.fileSize else {
				return sum
			}
			return sum + Int(fileSize)
		}
		
		// If size exceeds 100MB, show warning
		if totalSize > 100_000_000 {  // 100MB in bytes
			let content = UNMutableNotificationContent()
			content.title = "Storage Warning"
			content.body = "Time tracking data is using significant storage space. Consider cleaning up old data."
			
			let request = UNNotificationRequest(
				identifier: "storage-warning-\(Date().timeIntervalSince1970)",
				content: content,
				trigger: nil
			)
			
			UNUserNotificationCenter.current().add(request) { error in
				if let error = error {
					print("Error showing storage warning notification: \(error)")
				}
			}
		}
	}
	
	func getActivitiesForDate(_ date: Date) -> [Activity] {
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd"
		let fileName = dateFormatter.string(from: date) + ".json"
		let fileURL = storageURL.appendingPathComponent(fileName)
		
		guard let data = try? Data(contentsOf: fileURL),
			  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
			return []
		}
		
		return json.compactMap { dict in
			guard let application = dict["application"] as? String,
				  let title = dict["title"] as? String,
				  let path = dict["path"] as? String else {
				return nil
			}
			return Activity(application: application, title: title, path: path)
		}
	}
}
