//
//  ActivityRecord+CoreDataProperties.swift
//  TimeTracker
//
//  Created by Drew on 2/19/25.
//
//

import Foundation
import CoreData

extension ActivityRecord {

	@nonobjc public class func fetchRequest() -> NSFetchRequest<ActivityRecord> {
		return NSFetchRequest<ActivityRecord>(entityName: "ActivityRecord")
	}

	@NSManaged public var application: String?
	@NSManaged public var duration: Double
	@NSManaged public var path: String?
	@NSManaged public var projectNumber: String?
	@NSManaged public var timestamp: Date?
	@NSManaged public var title: String?
}

extension ActivityRecord : Identifiable {

}
