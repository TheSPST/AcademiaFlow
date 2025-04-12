import SwiftUI
import SwiftData

// Protocol for items that can be displayed in a list
protocol ListableItem: Identifiable {
    var displayTitle: String { get }
    var displayTimestamp: Date { get }
    var displayTags: [String] { get }
}

// Extension to make Document conform to ListableItem
extension Document: ListableItem {
    var displayTitle: String { title }
    var displayTimestamp: Date { updatedAt }
    var displayTags: [String] { tags }
}

// Extension to make PDF conform to ListableItem
extension PDF: ListableItem {
    var displayTitle: String { title ?? fileName }
    var displayTimestamp: Date { addedAt }
    var displayTags: [String] { tags }
}

// Extension to make Reference conform to ListableItem
extension Reference: ListableItem {
    var displayTitle: String { title }
    var displayTimestamp: Date { addedAt }
    var displayTags: [String] { [] } // Add tags support later
}

// Extension to make Note conform to ListableItem
extension Note: ListableItem {
    var displayTitle: String { title }
    var displayTimestamp: Date { timestamp }
    var displayTags: [String] { tags }
}
