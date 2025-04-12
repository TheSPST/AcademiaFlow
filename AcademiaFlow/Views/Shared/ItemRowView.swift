import SwiftUI

struct ItemRowView<T: ListableItem>: View {
    let item: T
    let subtitle: String?
    let metadata: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.displayTitle)
                .font(.headline)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if !item.displayTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(item.displayTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            if let metadata = metadata {
                Text(metadata)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
