import SwiftUI

struct PDFSidebarStack: View {
    @ObservedObject var viewModel: PDFViewModel
    
    var body: some View {
        Group {
            if viewModel.showBookmarks {
                PDFBookmarksSidebar(viewModel: viewModel)
                    .frame(width: 250)
            }
            
            if viewModel.showNotes {
                PDFNotesSidebar(viewModel: viewModel)
                    .frame(width: 250)
            }
            
            if viewModel.showChatView {
                PDFChatSidebar(viewModel: viewModel)
                    .frame(width: 300)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}
