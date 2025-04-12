import Foundation
import SwiftUI

enum SortOption {
    case modified, created, title, type
    
    var label: String {
        switch self {
        case .modified: return "Last Modified"
        case .created: return "Date Created"
        case .title: return "Title"
        case .type: return "Document Type"
        }
    }
}

// Move common sort menu view here
struct SortByMenuView: View {
    @Binding var sortOption: SortOption
    
    var body: some View {
        Menu {
            Picker("Sort by", selection: $sortOption) {
                Text("Last Modified").tag(SortOption.modified)
                Text("Date Created").tag(SortOption.created)
                Text("Title").tag(SortOption.title)
                Text("Type").tag(SortOption.type)
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }
}
