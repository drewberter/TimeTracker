import SwiftUI
import CoreData

struct ContentView: View {
	@Environment(\.managedObjectContext) private var viewContext
	@State private var selectedDate = Date()
	@State private var showingProjectsOnly = false
	@State private var selectedActivities: Set<NSManagedObjectID> = []
	@State private var showingBulkAssignmentSheet = false
	@State private var bulkProjectNumber = ""
	@State private var searchText = ""

	@FetchRequest(
		sortDescriptors: [NSSortDescriptor(keyPath: \ActivityRecord.timestamp, ascending: true)],
		animation: .default)
	private var activities: FetchedResults<ActivityRecord>
	
	var filteredActivities: [ActivityRecord] {
		if searchText.isEmpty {
			return Array(activities)
		} else {
			return activities.filter { activity in
				(activity.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
				(activity.application?.localizedCaseInsensitiveContains(searchText) ?? false) ||
				(activity.projectNumber?.localizedCaseInsensitiveContains(searchText) ?? false)
			}
		}
	}
	
	// Group activities by project
	private var groupedActivities: [String: [ActivityRecord]] {
		Dictionary(grouping: filteredActivities) { activity in
			activity.projectNumber ?? "Unassigned"
		}
	}
	
	// Calculate total duration for each project
	private func totalDuration(for project: String) -> Double {
		groupedActivities[project]?.reduce(0) { $0 + $1.duration } ?? 0
	}
	
	// Calculate total billable time for all projects
	private var totalBillableTime: Double {
		let allProjects = groupedActivities.keys
		return allProjects.reduce(0) { total, project in
			// Skip unassigned activities when calculating billable time
			if project == "Unassigned" {
				return total
			}
			return total + totalDuration(for: project)
		}
	}

	var body: some View {
		NavigationView {
			VStack {
				DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
					.datePickerStyle(.graphical)
					.padding()
					.onChange(of: selectedDate) { _, newDate in
						updateFetchRequest(for: newDate)
						selectedActivities.removeAll()
					}
				
				// Search bar
				HStack {
					Image(systemName: "magnifyingglass")
						.foregroundColor(.secondary)
					TextField("Search activities", text: $searchText)
						.textFieldStyle(.roundedBorder)
				}
				.padding(.horizontal)
				
				// View controls and summary info
				HStack {
					Text("View Mode:")
					Picker("View Mode", selection: $showingProjectsOnly) {
						Text("All Activities").tag(false)
						Text("By Project").tag(true)
					}
					.pickerStyle(.segmented)
					.frame(width: 200)
					
					Spacer()
					
					// Only show billable time if we have any
					if totalBillableTime > 0 {
						Text("Billable: \(formatDuration(totalBillableTime))")
							.bold()
							.padding(.horizontal)
					}
					
					Button(action: refreshActivities) {
						Label("Refresh", systemImage: "arrow.clockwise")
					}
				}
				.padding(.horizontal)
				
				// Multi-selection action bar
				if !selectedActivities.isEmpty {
					HStack {
						Text("\(selectedActivities.count) selected")
							.foregroundColor(.secondary)
							
						Spacer()
						
						Button(action: {
							showingBulkAssignmentSheet = true
						}) {
							Label("Assign Project", systemImage: "tag")
								.padding(.horizontal, 8)
								.padding(.vertical, 4)
								.background(Color.blue.opacity(0.1))
								.cornerRadius(6)
						}
						
						Button(action: {
							deleteSelectedActivities()
						}) {
							Label("Delete", systemImage: "trash")
								.padding(.horizontal, 8)
								.padding(.vertical, 4)
								.background(Color.red.opacity(0.1))
								.cornerRadius(6)
						}
					}
					.padding(.horizontal)
					.padding(.vertical, 8)
					.background(Color.secondary.opacity(0.1))
				}
				
				if showingProjectsOnly {
					// Project-grouped view
					List {
						ForEach(Array(groupedActivities.keys.sorted()), id: \.self) { project in
							Section(header: ProjectHeader(projectName: project, totalDuration: totalDuration(for: project))) {
								ForEach(groupedActivities[project] ?? []) { activity in
									ActivityRow(
										activity: activity,
										isSelected: selectedActivities.contains(activity.objectID),
										onToggle: { toggleSelection(activity) }
									)
									.swipeActions {
										Button(role: .destructive) {
											deleteActivity(activity)
										} label: {
											Label("Delete", systemImage: "trash")
										}
									}
								}
							}
						}
					}
					// No list style for macOS compatibility
				} else {
					// Chronological view
					List {
						ForEach(filteredActivities, id: \.objectID) { activity in
							ActivityRow(
								activity: activity,
								isSelected: selectedActivities.contains(activity.objectID),
								onToggle: { toggleSelection(activity) }
							)
							.swipeActions {
								Button {
									showProjectAssignmentSheet(for: activity)
								} label: {
									Label("Assign", systemImage: "tag")
								}
								.tint(.blue)
								
								Button(role: .destructive) {
									deleteActivity(activity)
								} label: {
									Label("Delete", systemImage: "trash")
								}
							}
						}
					}
					.listStyle(.grouped) // Changed from .insetGrouped to .grouped
				}
			}
			.toolbar {
				ToolbarItem(placement: .primaryAction) {
					Button(action: refreshActivities) {
						Label("Refresh", systemImage: "arrow.clockwise")
					}
				}
				
				ToolbarItem(placement: .automatic) {
					Menu {
						Button(action: {
							selectedActivities = Set(activities.map { $0.objectID })
						}) {
							Label("Select All", systemImage: "checkmark.circle")
						}
						
						if !selectedActivities.isEmpty {
							Button(action: {
								selectedActivities.removeAll()
							}) {
								Label("Deselect All", systemImage: "xmark.circle")
							}
						}
						
						Divider()
						
						Button(action: exportData) {
							Label("Export Data", systemImage: "square.and.arrow.up")
						}
					} label: {
						Label("More", systemImage: "ellipsis.circle")
					}
				}
			}
			.navigationTitle("Time Tracker")
			.sheet(isPresented: $showingBulkAssignmentSheet) {
				BulkProjectAssignmentView(
					projectNumber: $bulkProjectNumber,
					onAssign: assignProjectToBulk
				)
			}
			
			// Default detail view
			Text("Select an activity to see details")
		}
		.onAppear {
			// Initial fetch request setup
			updateFetchRequest(for: selectedDate)
		}
	}

	private func updateFetchRequest(for date: Date) {
		let calendar = Calendar.current
		let startOfDay = calendar.startOfDay(for: date)
		let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
		
		let predicate = NSPredicate(format: "timestamp >= %@ AND timestamp < %@",
								  startOfDay as NSDate,
								  endOfDay as NSDate)
		
		activities.nsPredicate = predicate
	}

	private func refreshActivities() {
		// Direct access to ActivityTracker
		ActivityTracker.shared.checkCurrentActivity()
		
		// Refresh the fetch request
		updateFetchRequest(for: selectedDate)
	}
	
	private func toggleSelection(_ activity: ActivityRecord) {
		if selectedActivities.contains(activity.objectID) {
			selectedActivities.remove(activity.objectID)
		} else {
			selectedActivities.insert(activity.objectID)
		}
	}
	
	private func showProjectAssignmentSheet(for activity: ActivityRecord) {
		// Set the selected activity and show sheet for individual assignment
		selectedActivities = [activity.objectID]
		bulkProjectNumber = activity.projectNumber ?? ""
		showingBulkAssignmentSheet = true
	}
	
	private func assignProjectToBulk() {
		// Assign the project number to all selected activities
		for objectID in selectedActivities {
			if let activity = try? viewContext.existingObject(with: objectID) as? ActivityRecord {
				activity.projectNumber = bulkProjectNumber
			}
		}
		
		// Update project matcher with the new project
		if !bulkProjectNumber.isEmpty {
			ProjectMatcher.shared.updateRecentProjects(bulkProjectNumber)
		}
		
		// Save changes
		saveContext()
		
		// Clear selection and close sheet
		showingBulkAssignmentSheet = false
		selectedActivities.removeAll()
	}
	
	private func deleteActivity(_ activity: ActivityRecord) {
		withAnimation {
			viewContext.delete(activity)
			saveContext()
		}
	}
	
	private func deleteSelectedActivities() {
		withAnimation {
			for objectID in selectedActivities {
				if let activity = try? viewContext.existingObject(with: objectID) as? ActivityRecord {
					viewContext.delete(activity)
				}
			}
			saveContext()
			selectedActivities.removeAll()
		}
	}
	
	private func exportData() {
		// Implementation would create CSV export of current view
		// This is a placeholder for future implementation
		print("Export functionality would go here")
	}
	
	private func saveContext() {
		do {
			try viewContext.save()
		} catch {
			let nsError = error as NSError
			print("Unresolved error \(nsError), \(nsError.userInfo)")
		}
	}
	
	private func formatDuration(_ duration: Double) -> String {
		let hours = Int(duration) / 3600
		let minutes = Int(duration) / 60 % 60
		if hours > 0 {
			return "\(hours)h \(minutes)m"
		}
		return "\(minutes)m"
	}
}

// Project header with name and total duration
struct ProjectHeader: View {
	let projectName: String
	let totalDuration: Double
	
	var body: some View {
		HStack {
			Text(projectName)
				.font(.headline)
			Spacer()
			Text("Total: \(formatDuration(totalDuration))")
				.font(.subheadline)
				.foregroundColor(.secondary)
		}
	}
	
	private func formatDuration(_ duration: Double) -> String {
		let hours = Int(duration) / 3600
		let minutes = Int(duration) / 60 % 60
		if hours > 0 {
			return "\(hours)h \(minutes)m"
		}
		return "\(minutes)m"
	}
}

struct ActivityRow: View {
	let activity: ActivityRecord
	let isSelected: Bool
	let onToggle: () -> Void
	
	var body: some View {
		HStack {
			Button(action: onToggle) {
				Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
					.foregroundColor(isSelected ? .blue : .gray)
			}
			.buttonStyle(BorderlessButtonStyle())
			
			VStack(alignment: .leading, spacing: 4) {
				Text(activity.title ?? "Unknown")
					.font(.headline)
				HStack {
					Text(activity.application ?? "Unknown App")
						.font(.subheadline)
						.foregroundColor(.secondary)
					Spacer()
					Text(formatDuration(activity.duration))
						.font(.subheadline)
						.foregroundColor(.secondary)
				}
				if let projectNumber = activity.projectNumber, !projectNumber.isEmpty {
					Text("Project: \(projectNumber)")
						.font(.caption)
						.foregroundColor(.blue)
						.padding(.vertical, 2)
						.padding(.horizontal, 6)
						.background(Color.blue.opacity(0.1))
						.cornerRadius(4)
				}
			}
		}
		.padding(.vertical, 2)
		.contentShape(Rectangle())
		.onTapGesture {
			onToggle()
		}
	}
	
	private func formatDuration(_ duration: Double) -> String {
		let hours = Int(duration) / 3600
		let minutes = Int(duration) / 60 % 60
		if hours > 0 {
			return "\(hours)h \(minutes)m"
		}
		return "\(minutes)m"
	}
}

struct BulkProjectAssignmentView: View {
	@Environment(\.dismiss) var dismiss
	@Binding var projectNumber: String
	@State private var recentProjects: [String] = []
	let onAssign: () -> Void
	
	var body: some View {
		NavigationView {
			Form {
				Section(header: Text("Project Number")) {
					TextField("Enter Project Number", text: $projectNumber)
						// Remove autocapitalization which is unavailable in macOS
				}
				
				Section(header: Text("Recent Projects")) {
					ForEach(recentProjects, id: \.self) { project in
						Button(action: {
							projectNumber = project
						}) {
							HStack {
								Text(project)
								Spacer()
								if projectNumber == project {
									Image(systemName: "checkmark")
										.foregroundColor(.blue)
								}
							}
						}
						.buttonStyle(BorderlessButtonStyle())
					}
				}
			}
			.navigationTitle("Assign Project")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						dismiss()
					}
				}
				
				ToolbarItem(placement: .confirmationAction) {
					Button("Assign") {
						onAssign()
					}
				}
			}
			.onAppear {
				// Fetch recent projects from ProjectMatcher
				recentProjects = ProjectMatcher.shared.getRecentProjects()
			}
		}
	}
}

#Preview {
	ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
