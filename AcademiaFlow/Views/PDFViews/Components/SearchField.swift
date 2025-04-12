import SwiftUI

struct SearchField: View {
    @Binding var text: String
    let isSearching: Bool
    let currentResult: Int
    let totalResults: Int
    let onSearch: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search in PDF", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: text) { _, _ in
                        onSearch()
                    }
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            if isSearching {
                HStack(spacing: 8) {
                    Text("\(currentResult) of \(totalResults)")
                        .monospacedDigit()
                    
                    Button(action: onPrevious) {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(totalResults == 0)
                    
                    Button(action: onNext) {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(totalResults == 0)
                }
            }
        }
    }
}