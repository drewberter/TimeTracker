import Foundation

class ProjectMatcher {
	static let shared = ProjectMatcher()
	private var recentProjects: [String] = []  // Store recent project numbers
	
	func guessProject(title: String, path: String) -> String? {
		// First check if title contains a project number
		if let projectNum = findProjectNumber(in: title) {
			updateRecentProjects(projectNum)
			return projectNum
		}
		
		// Then check the path
		if let projectNum = findProjectNumber(in: path) {
			updateRecentProjects(projectNum)
			return projectNum
		}
		
		// If nothing found in title or path, check if project can be detected from folder path
		if !path.isEmpty {
			if let projectNum = matchProjectFromPath(path) {
				updateRecentProjects(projectNum)
				return projectNum
			}
		}
		
		// Check recent projects as a fallback
		return recentProjects.first
	}
	
	private func findProjectNumber(in text: String) -> String? {
		// Common project number formats
		let patterns = [
			// Match "BMS 1234" or similar project codes
			"\\b(BMS|PJT|PRJ)\\s*[0-9]{4,}\\b",
			// Match project-1234 format
			"\\bproject[-_]?[0-9]{4,}\\b",
			// Match #1234 format
			"#[0-9]{4,}\\b"
		]
		
		for pattern in patterns {
			if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
			   let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
				
				if let range = Range(match.range, in: text) {
					let matchedString = String(text[range])
					// Clean up the matched string (remove spaces)
					return matchedString.replacingOccurrences(of: " ", with: "")
				}
			}
		}
		
		return nil
	}
	
	private func matchProjectFromPath(_ path: String) -> String? {
		// Try to extract project from folder path
		let url = URL(fileURLWithPath: path)
		let folders = url.pathComponents
		
		// Check if any folder name contains a project number pattern
		for folder in folders {
			if let projectNum = findProjectNumber(in: folder) {
				return projectNum
			}
		}
		
		return nil
	}
	
	func updateRecentProjects(_ projectNumber: String) {
		// Keep track of recently used projects
		recentProjects.removeAll { $0 == projectNumber }
		recentProjects.insert(projectNumber, at: 0)
		if recentProjects.count > 5 {  // Keep only last 5 projects
			recentProjects.removeLast()
		}
	}
	
	// Helper method for Activity struct
	func guessProject(for activity: Activity) -> String? {
		return guessProject(title: activity.title, path: activity.path)
	}
}
