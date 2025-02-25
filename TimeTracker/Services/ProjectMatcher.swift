import Foundation

class ProjectMatcher {
    static let shared = ProjectMatcher()
    private var recentProjects: [String] = []  // Store recent project numbers
    
    func guessProject(for activity: Activity) -> String? {
        // Check if activity title contains a project number
        if let projectNumber = findProjectNumber(in: activity.title) {
            return projectNumber
        }
        
        // Check if the application/path matches known patterns
        if let match = matchProjectFromPath(activity.path) {
            return match
        }
        
        // Check recent projects as a fallback
        return recentProjects.first
    }
    
    private func findProjectNumber(in text: String) -> String? {
        // Look for patterns like "BMS 1188" or similar project numbers
        let pattern = "BMS\\s*\\d{4}"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
            let matchedString = String(text[Range(match.range, in: text)!])
            return matchedString.replacingOccurrences(of: " ", with: "")
        }
        return nil
    }
    
    private func matchProjectFromPath(_ path: String) -> String? {
        // Implementation to match project based on file path patterns
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
}