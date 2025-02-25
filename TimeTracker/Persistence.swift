//
//  Persistence.swift
//  TimeTracker
//
//  Created by Drew on 2/18/25.
//

import CoreData

struct PersistenceController {
	static let shared = PersistenceController()
	
	static var preview: PersistenceController = {
		let result = PersistenceController(inMemory: true)
		let viewContext = result.container.viewContext
		for i in 0..<5 {
			let newActivity = ActivityRecord(context: viewContext)
			newActivity.timestamp = Date()
			newActivity.title = "Sample Activity \(i)"
			newActivity.application = "Test App"
			newActivity.duration = Double(i * 300) // 5-minute intervals
			newActivity.projectNumber = "BMS \(1180 + i)"
		}
		do {
			try viewContext.save()
		} catch {
			let nsError = error as NSError
			fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
		}
		return result
	}()
	
	let container: NSPersistentContainer
	
	init(inMemory: Bool = false) {
		container = NSPersistentContainer(name: "TimeTracker")
		if inMemory {
			container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
		}
		container.loadPersistentStores(completionHandler: { (storeDescription, error) in
			if let error = error as NSError? {
				fatalError("Unresolved error \(error), \(error.userInfo)")
			}
		})
		container.viewContext.automaticallyMergesChangesFromParent = true
	}
	
	func saveActivity(application: String, title: String, path: String, duration: TimeInterval) {
		let context = container.viewContext
		let activityRecord = ActivityRecord(context: context)
		
		activityRecord.application = application
		activityRecord.title = title
		activityRecord.path = path
		activityRecord.duration = duration
		activityRecord.timestamp = Date()
		
		do {
			try context.save()
		} catch {
			print("Failed to save activity: \(error)")
		}
	}
}
