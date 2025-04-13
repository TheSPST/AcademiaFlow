import SwiftUI
import SwiftData

struct FloatingChatButton: View {
    @State private var showChat = false
    @State private var dragOffset = CGSize.zero
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack {
            if showChat {
                QueryChatView(isPresented: $showChat)
                    .frame(height: 400)
                    .transition(.move(edge: .bottom))
            }
            
            Button(action: { withAnimation { showChat.toggle() } }) {
                Image(systemName: showChat ? "xmark.circle.fill" : "bubble.left.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(showChat ? .red : .blue)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(radius: 5)
            }
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        withAnimation {
                            dragOffset = CGSize(
                                width: value.translation.width,
                                height: max(0, value.translation.height)
                            )
                        }
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding()
    }
}