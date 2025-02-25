import SwiftUI
import CoreData

struct ContentView: View {
	@Environment(\.managedObjectContext) private var viewContext
	@State private var selectedDate = Date()
	@State private var showingProjectsOnly = false

	@FetchRequest(
		sortDescriptors: [NSSortDescriptor(keyPath: \ActivityRecord.timestamp, ascending: true)],
		animation: .default)
	private var activities: FetchedResults<ActivityRecord>
	
	// Group activities by project
	private var groupedActivities: [String: [ActivityRecord]] {
		Dictionary(grouping: activities) { activity in
			activity.projectNumber ?? "Unassigned"
		}
	}
	
	// Calculate total duration for each project
	private func totalDuration(for project: String) -> Double {
		groupedActivities[project]?.reduce(0) { $0 + $1.duration } ?? 0
	}

	var body: some View {
		NavigationView {
			VStack {
				DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
					.datePickerStyle(.graphical)
					.padding()
					.onChange(of: selectedDate) { _, newDate in
						updateFetchRequest(for: newDate)
					}
				
				HStack {
					Text("View Mode:")
					Picker("View Mode", selection: $showingProjectsOnly) {
						Text("All Activities").tag(false)
						Text("By Project").tag(true)
					}
					.pickerStyle(.segmented)
					.frame(width: 200)
					
					Spacer()
					
					Button(action: refreshActivities) {
						Label("Refresh", systemImage: "arrow.clockwise")
					}
				}
				.padding(.horizontal)
				
				if showingProjectsOnly {
					// Project-grouped view
					List {
						ForEach(Array(groupedActivities.keys.sorted()), id: \.self) { project in
							Section(header: ProjectHeader(projectName: project, totalDuration: totalDuration(for: project))) {
								ForEach(groupedActivities[project] ?? []) { activity in
									NavigationLink {
										ActivityDetailView(activity: activity)
									} label: {
										ActivityRow(activity: activity)
									}
								}
								.onDelete { indexSet in
									deleteActivities(at: indexSet, from: project)
								}
							}
						}
					}
				} else {
					// Chronological view (original)
					List {
						ForEach(activities) { activity in
							NavigationLink {
								ActivityDetailView(activity: activity)
							} label: {
								ActivityRow(activity: activity)
							}
						}
						.onDelete(perform: deleteActivities)
					}
				}
			}
			.toolbar {
				ToolbarItem(placement: .primaryAction) {
					Button(action: refreshActivities) {
						Label("Refresh", systemImage: "arrow.clockwise")
					}
				}
			}
			.navigationTitle("Time Tracker")
			
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
		// Direct access to ActivityTracker without going through AppDelegate
		ActivityTracker.shared.checkCurrentActivity()
		
		// Refresh the fetch request
		updateFetchRequest(for: selectedDate)
	}

	private func deleteActivities(offsets: IndexSet) {
		withAnimation {
			offsets.map { activities[$0] }.forEach(viewContext.delete)
			saveContext()
		}
	}
	
	private func deleteActivities(at offsets: IndexSet, from project: String) {
		withAnimation {
			let activitiesToDelete = offsets.map { groupedActivities[project]![$0] }
			activitiesToDelete.forEach(viewContext.delete)
			saveContext()
		}
	}
	
	private func saveContext() {
		do {
			try viewContext.save()
		} catch {
			let nsError = error as NSError
			print("Unresolved error \(nsError), \(nsError.userInfo)")
		}
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
	
	var body: some View {
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
			if let projectNumber = activity.projectNumber {
				Text("Project: \(projectNumber)")
					.font(.caption)
					.foregroundColor(.blue)
			}
		}
		.padding(.vertical, 2)
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

struct ActivityDetailView: View {
	let activity: ActivityRecord
	@Environment(\.managedObjectContext) private var viewContext
	@State private var projectNumber: String
	
	init(activity: ActivityRecord) {
		self.activity = activity
		_projectNumber = State(initialValue: activity.projectNumber ?? "")
	}
	
	var body: some View {
		Form {
			Section(header: Text("Activity Details")) {
				LabeledContent("Application", value: activity.application ?? "Unknown")
				LabeledContent("Title", value: activity.title ?? "Unknown")
				if let timestamp = activity.timestamp {
					LabeledContent("Time", value: timestamp, format: .dateTime)
				}
				LabeledContent("Duration", value: formatDuration(activity.duration))
			}
			
			Section(header: Text("Project Assignment")) {
				TextField("Project Number", text: $projectNumber)
					.textFieldStyle(.roundedBorder)
					.onChange(of: projectNumber) { _, newValue in
						updateProjectNumber(newValue)
					}
			}
		}
		.padding()
		.navigationTitle("Activity Details")
	}
	
	private func formatDuration(_ duration: Double) -> String {
		let hours = Int(duration) / 3600
		let minutes = Int(duration) / 60 % 60
		if hours > 0 {
			return "\(hours) hours \(minutes) minutes"
		}
		return "\(minutes) minutes"
	}
	
	private func updateProjectNumber(_ newValue: String) {
		activity.projectNumber = newValue
		do {
			try viewContext.save()
		} catch {
			print("Failed to save project number: \(error)")
		}
	}
}

#Preview {
	ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
