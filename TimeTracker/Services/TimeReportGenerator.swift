//
//  TimeReportGenerator.swift
//  TimeTracker
//
//  Created by Drew on 2/25/25.
//


import Foundation
import CoreData

class TimeReportGenerator {
    static let shared = TimeReportGenerator()
    
    func generateTimeReport(from startDate: Date, to endDate: Date, project: String? = nil) -> String {
        // Header row
        var report = "Project,Date,Start Time,Duration,Activity,Application\n"
        
        // Fetch activities in the date range
        let activities = fetchActivities(from: startDate, to: endDate, project: project)
        
        // Group by project and date
        let grouped = groupActivities(activities)
        
        // Generate CSV rows
        for (project, dateDict) in grouped {
            for (date, projectActivities) in dateDict {
                // Sort by start time
                let sorted = projectActivities.sorted { 
                    ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) 
                }
                
                for activity in sorted {
                    let line = formatActivityForReport(activity, project: project, date: date)
                    report += line + "\n"
                }
            }
        }
        
        return report
    }
    
    private func fetchActivities(from startDate: Date, to endDate: Date, project: String? = nil) -> [ActivityRecord] {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<ActivityRecord> = ActivityRecord.fetchRequest()
        
        // Date range predicate
        let datePredicate = NSPredicate(
            format: "timestamp >= %@ AND timestamp <= %@",
            startDate as NSDate,
            endDate as NSDate
        )
        
        // Project filter if specified
        if let project = project, !project.isEmpty {
            let projectPredicate = NSPredicate(format: "projectNumber == %@", project)
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, projectPredicate])
        } else {
            // If no specific project, only include activities with project numbers
            let hasProjectPredicate = NSPredicate(format: "projectNumber != nil AND projectNumber != ''")
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, hasProjectPredicate])
        }
        
        // Sort by project, date, and time
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \ActivityRecord.projectNumber, ascending: true),
            NSSortDescriptor(keyPath: \ActivityRecord.timestamp, ascending: true)
        ]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error fetching activities for report: \(error)")
            return []
        }
    }
    
    private func groupActivities(_ activities: [ActivityRecord]) -> [String: [Date: [ActivityRecord]]] {
        let calendar = Calendar.current
        var result: [String: [Date: [ActivityRecord]]] = [:]
        
        for activity in activities {
            guard let timestamp = activity.timestamp,
                  let projectNumber = activity.projectNumber, !projectNumber.isEmpty else {
                continue
            }
            
            // Get date without time component
            let date = calendar.startOfDay(for: timestamp)
            
            // Initialize if needed
            if result[projectNumber] == nil {
                result[projectNumber] = [:]
            }
            
            if result[projectNumber]![date] == nil {
                result[projectNumber]![date] = []
            }
            
            // Add activity to its group
            result[projectNumber]![date]!.append(activity)
        }
        
        return result
    }
    
    private func formatActivityForReport(_ activity: ActivityRecord, project: String, date: Date) -> String {
        // Format date as YYYY-MM-DD
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // Format time as HH:MM AM/PM
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = timeFormatter.string(from: activity.timestamp ?? Date())
        
        // Format duration as decimal hours
        let hoursDecimal = String(format: "%.2f", activity.duration / 3600.0)
        
        // Clean strings for CSV (escape quotes, remove commas)
        let cleanProject = escapeCsvField(project)
        let cleanTitle = escapeCsvField(activity.title ?? "Unknown")
        let cleanApp = escapeCsvField(activity.application ?? "Unknown")
        
        // Assemble CSV line
        return "\(cleanProject),\(dateString),\(timeString),\(hoursDecimal),\(cleanTitle),\(cleanApp)"
    }
    
    private func escapeCsvField(_ field: String) -> String {
        // If field contains quotes, commas, or newlines, wrap in quotes and escape internal quotes
        if field.contains("\"") || field.contains(",") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
    
    // Helper method to export a timesheet for a specific project
    func exportProjectTimesheet(project: String, from startDate: Date, to endDate: Date) -> Data? {
        let report = generateTimeReport(from: startDate, to: endDate, project: project)
        return report.data(using: .utf8)
    }
}