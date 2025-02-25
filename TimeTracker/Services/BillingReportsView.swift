//
//  BillingReportsView.swift
//  TimeTracker
//
//  Created by Drew on 2/25/25.
//


import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct BillingReportsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedProject: String? = nil
    @State private var isExporting = false
    @State private var csvData: String = ""
    
    // Get all activities in the date range
    private var filteredActivities: [ActivityRecord] {
        let fetchRequest: NSFetchRequest<ActivityRecord> = ActivityRecord.fetchRequest()
        
        // Create date range predicate
        let datePredicate = NSPredicate(
            format: "timestamp >= %@ AND timestamp <= %@",
            startDate as NSDate,
            endDate as NSDate
        )
        
        // Add project filter if a project is selected
        var predicates: [NSPredicate] = [datePredicate]
        if let project = selectedProject {
            let projectPredicate = NSPredicate(format: "projectNumber == %@", project)
            predicates.append(projectPredicate)
        }
        
        // Combine predicates if needed
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \ActivityRecord.projectNumber, ascending: true),
            NSSortDescriptor(keyPath: \ActivityRecord.timestamp, ascending: true)
        ]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching activities: \(error)")
            return []
        }
    }
    
    // Group activities by project
    private var groupedActivities: [String: [ActivityRecord]] {
        Dictionary(grouping: filteredActivities) { activity in
            activity.projectNumber ?? "Unassigned"
        }
    }
    
    // Get all available projects
    private var availableProjects: [String] {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ActivityRecord.fetchRequest()
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = ["projectNumber"]
        fetchRequest.returnsDistinctResults = true
        
        do {
            let results = try viewContext.fetch(fetchRequest) as? [[String: Any]] ?? []
            return results.compactMap { $0["projectNumber"] as? String }.filter { !$0.isEmpty }.sorted()
        } catch {
            print("Error fetching projects: \(error)")
            return []
        }
    }
    
    // Calculate total billable time
    private var totalBillableTime: Double {
        filteredActivities
            .filter { $0.projectNumber != nil && !$0.projectNumber!.isEmpty }
            .reduce(0) { $0 + $1.duration }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Date Range")) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                    
                    Button("This Week") {
                        let calendar = Calendar.current
                        let today = Date()
                        startDate = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: today).date!
                        endDate = today
                    }
                    
                    Button("This Month") {
                        let calendar = Calendar.current
                        let today = Date()
                        let components = calendar.dateComponents([.year, .month], from: today)
                        startDate = calendar.date(from: components)!
                        endDate = today
                    }
                }
                
                Section(header: Text("Project Filter")) {
                    Picker("Filter by Project", selection: $selectedProject) {
                        Text("All Projects").tag(nil as String?)
                        ForEach(availableProjects, id: \.self) { project in
                            Text(project).tag(project as String?)
                        }
                    }
                }
                
                Section(header: Text("Summary")) {
                    HStack {
                        Text("Total Billable Time")
                        Spacer()
                        Text(formatDuration(totalBillableTime))
                            .bold()
                    }
                    
                    Button(action: exportTimesheet) {
                        Label("Export Timesheet", systemImage: "square.and.arrow.up")
                    }
                }
                
                // List projects and their total times
                Section(header: Text("Projects")) {
                    ForEach(Array(groupedActivities.keys.sorted()), id: \.self) { project in
                        NavigationLink(destination: ProjectDetailView(
                            project: project,
                            activities: groupedActivities[project] ?? []
                        )) {
                            HStack {
                                Text(project)
                                Spacer()
                                let total = groupedActivities[project]?.reduce(0) { $0 + $1.duration } ?? 0
                                Text(formatDuration(total))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Billing Reports")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: refreshData) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: CsvDocument(data: csvData),
                contentType: .commaSeparatedText,
                defaultFilename: "TimeReport_\(formattedDate(startDate))_\(formattedDate(endDate))"
            ) { result in
                switch result {
                case .success(let url):
                    print("Exported to \(url)")
                case .failure(let error):
                    print("Export failed: \(error)")
                }
            }
            
            // Default detail view
            Text("Select a project to see details")
        }
    }
    
    private func exportTimesheet() {
        // Generate CSV data
        var csv = "Project,Date,Application,Title,Duration (hours),Duration (minutes)\n"
        
        for activity in filteredActivities {
            let project = activity.projectNumber ?? "Unassigned"
            let date = formattedDate(activity.timestamp ?? Date())
            let app = activity.application?.replacingOccurrences(of: ",", with: " ") ?? "Unknown"
            let title = activity.title?.replacingOccurrences(of: ",", with: " ") ?? "Unknown"
            let durationHours = Int(activity.duration) / 3600
            let durationMinutes = Int(activity.duration) / 60 % 60
            
            csv += "\"\(project)\",\"\(date)\",\"\(app)\",\"\(title)\",\(durationHours),\(durationMinutes)\n"
        }
        
        // Set the CSV data for export
        csvData = csv
        isExporting = true
    }
    
    private func refreshData() {
        // This is a placeholder - would actually refresh the fetch
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        return String(format: "%dh %02dm", hours, minutes)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct ProjectDetailView: View {
    let project: String
    let activities: [ActivityRecord]
    
    // Group activities by day
    private var activitiesByDay: [Date: [ActivityRecord]] {
        let calendar = Calendar.current
        return Dictionary(grouping: activities) { activity in
            let date = activity.timestamp ?? Date()
            return calendar.startOfDay(for: date)
        }
    }
    
    // Sort days in descending order
    private var sortedDays: [Date] {
        activitiesByDay.keys.sorted(by: >)
    }
    
    var body: some View {
        List {
            Section(header: Text("Summary")) {
                let totalDuration = activities.reduce(0) { $0 + $1.duration }
                HStack {
                    Text("Total Time")
                    Spacer()
                    Text(formatDuration(totalDuration))
                        .bold()
                }
                
                HStack {
                    Text("Activity Count")
                    Spacer()
                    Text("\(activities.count)")
                }
            }
            
            ForEach(sortedDays, id: \.self) { day in
                Section(header: Text(formattedDay(day))) {
                    ForEach(activitiesByDay[day] ?? [], id: \.objectID) { activity in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(activity.application ?? "Unknown")
                                    .font(.headline)
                                Spacer()
                                Text(formatTime(activity.timestamp ?? Date()))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(activity.title ?? "Unknown")
                                .font(.body)
                                .lineLimit(2)
                            
                            HStack {
                                Spacer()
                                Text(formatDuration(activity.duration))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(project)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        return String(format: "%dm", minutes)
    }
    
    private func formattedDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// Document type for CSV export
struct CsvDocument: FileDocument {
    static var readableContentTypes: [UTType] = [UTType.commaSeparatedText]
    
    var data: String
    
    init(data: String) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(data.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}

// Add this to AppDelegate's setup Menu function
func addReportsToMenu() {
    // Add a Reports menu item between Open Dashboard and Toggle Tracking
    menu.addItem(NSMenuItem(title: "Billing Reports", action: #selector(openReports), keyEquivalent: "r"))
}

// Add this method to AppDelegate
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