import SwiftUI
import SwiftData

struct GenericListView<T: ListableItem, RowContent: View>: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var searchText: String
    @Binding var sortOption: SortOption
    let items: [T]
    let title: String
    let rowContent: (T) -> RowContent
    let onDelete: (T) -> Void
    let onDuplicate: ((T) -> Void)?
    
    var filteredAndSortedItems: [T] {
        let filtered = searchText.isEmpty ? items : items.filter { item in
            item.displayTitle.localizedCaseInsensitiveContains(searchText) ||
            item.displayTags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        
        return filtered.sorted { item1, item2 in
            switch sortOption {
            case .modified, .created:
                return item1.displayTimestamp > item2.displayTimestamp
            case .title, .type:
                return item1.displayTitle < item2.displayTitle
            }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredAndSortedItems) { item in
                rowContent(item)
                    .swipeActions(edge: .leading) {
                        if let duplicate = onDuplicate {
                            Button {
                                duplicate(item)
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                            .tint(.blue)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            onDelete(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        GenericContextMenu(
                            item: item,
                            onDuplicate: onDuplicate,
                            onDelete: onDelete
                        )
                    }
            }
        }
        .navigationTitle(title)
        .searchable(text: $searchText, prompt: "Search \(title)")
    }
}

struct GenericContextMenu<T>: View {
    let item: T
    let onDuplicate: ((T) -> Void)?
    let onDelete: (T) -> Void
    
    var body: some View {
        if let duplicate = onDuplicate {
            Button {
                duplicate(item)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
        }
        
        Button(role: .destructive) {
            onDelete(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
