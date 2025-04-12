import SwiftUI

struct ViewToggleButtons: View {
    @ObservedObject var viewModel: PDFViewModel
    
    var body: some View {
        Group {
            Toggle(isOn: $viewModel.showThumbnailView) {
                Label("Thumbnails", systemImage: "sidebar.left")
            }
            .toggleStyle(.button)
            
            Toggle(isOn: $viewModel.showBookmarks) {
                Label("Bookmarks", systemImage: "bookmark")
            }
            .toggleStyle(.button)
            
            Toggle(isOn: $viewModel.showNotes) {
                Label("Notes", systemImage: "note.text")
            }
            .toggleStyle(.button)
            
            Toggle(isOn: $viewModel.showChatView) {
                Label("Chat", systemImage: "bubble.left.and.bubble.right")
            }
            .toggleStyle(.button)
        }
    }
}