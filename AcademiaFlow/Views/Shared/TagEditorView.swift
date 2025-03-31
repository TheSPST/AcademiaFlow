import SwiftUI

struct TagEditorView: View {
    @Binding var tags: [String]
    @State private var newTag = ""
    @State private var isEditing = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tags Flow Layout
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    TagView(tag: tag) {
                        removeTag(tag)
                    }
                }
                
                // Add Tag Button or TextField
                if isEditing {
                    TextField("Add tag", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .focused($isFocused)
                        .onSubmit(addTag)
                        .onAppear {
                            isFocused = true
                        }
                } else {
                    AddTagButton {
                        isEditing = true
                    }
                }
            }
        }
        .onTapGesture {
            if !isEditing {
                isEditing = true
            }
        }
    }
    
    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tag.isEmpty && !tags.contains(tag) {
            tags.append(tag)
        }
        newTag = ""
        isEditing = false
    }
    
    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}

struct TagView: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(Color.accentColor.opacity(0.1))
        }
    }
}

struct AddTagButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.caption)
                Text("Add Tag")
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = generateRows(proposal: proposal, subviews: subviews)
        return computeSize(rows: rows)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = generateRows(proposal: proposal, subviews: subviews)
        placeViews(rows: rows, in: bounds)
    }
    
    private func generateRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var currentRow = 0
        var remainingWidth = proposal.width ?? 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentRow == 0 || size.width > remainingWidth {
                if currentRow > 0 {
                    currentRow += 1
                    rows.append([])
                }
                rows[currentRow].append(subview)
                remainingWidth = (proposal.width ?? 0) - size.width - spacing
            } else {
                rows[currentRow].append(subview)
                remainingWidth -= size.width + spacing
            }
        }
        
        return rows
    }
    
    private func computeSize(rows: [[LayoutSubview]]) -> CGSize {
        var height: CGFloat = 0
        var width: CGFloat = 0
        
        for row in rows {
            var rowWidth: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
            
            width = max(width, rowWidth)
            height += rowHeight + spacing
        }
        
        return CGSize(width: width - spacing, height: height - spacing)
    }
    
    private func placeViews(rows: [[LayoutSubview]], in bounds: CGRect) {
        var y = bounds.minY
        
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            
            y += rowHeight + spacing
        }
    }
}

#Preview {
    TagEditorView(tags: .constant(["SwiftUI", "iOS", "macOS", "Programming", "Swift"]))
        .padding()
}
