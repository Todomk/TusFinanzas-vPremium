import Foundation

extension String {
    func trimWhitespace() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
} 