import Foundation

enum StudyTimeDisplay {
    static func short(_ seconds: Double) -> String {
        let minutes = Int(max(0, seconds) / 60)
        return "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m"
    }
}
