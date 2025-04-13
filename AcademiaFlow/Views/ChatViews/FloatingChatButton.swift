import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct FloatingChatButton: View {
    @State private var showChat = false
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @Binding var selectedNavigation: NavigationType?
    @Binding var selectedDocument: Document?
    @Binding var selectedPDF: PDF?
    @Binding var selectedNote: Note?
    @Binding var selectedReference: Reference?
    
    @State private var isAnimating = false
    @State private var showPulse = false
    
    private var screenWidth: CGFloat {
        #if os(iOS)
        UIScreen.main.bounds.width
        #else
        NSScreen.main?.frame.width ?? 1024
        #endif
    }
    
    var body: some View {
        VStack {
            if showChat {
                QueryChatView(
                    isPresented: $showChat,
                    selectedNavigation: $selectedNavigation,
                    selectedDocument: $selectedDocument,
                    selectedPDF: $selectedPDF,
                    selectedNote: $selectedNote,
                    selectedReference: $selectedReference
                )
                .frame(height: 400)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            Button(action: toggleChat) {
                ZStack {
                    if showPulse && !showChat {
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .scaleEffect(isAnimating ? 1.5 : 1.0)
                            .opacity(isAnimating ? 0 : 0.5)
                    }
                    
                    Image(systemName: showChat ? "xmark.circle.fill" : "bubble.left.circle.fill")
                        .font(.system(size: 32))
                        .symbolEffect(.bounce, value: isAnimating)
                        .foregroundStyle(showChat ? Color.red : Color.blue)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(
                            color: (showChat ? Color.red : Color.blue).opacity(0.3),
                            radius: isDragging ? 10 : 5,
                            x: 0,
                            y: isDragging ? 8 : 4
                        )
                        .scaleEffect(isDragging ? 1.1 : 1.0)
                }
            }
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        isDragging = false
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            let buttonWidth: CGFloat = 80
                            dragOffset.width = value.translation.width > screenWidth/2 ?
                                screenWidth - buttonWidth : 0
                            dragOffset.height = max(0, value.translation.height)
                        }
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding()
        .onAppear(perform: startPulseAnimation)
    }
    
    private func toggleChat() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showChat.toggle()
            isAnimating.toggle()
        }
    }
    
    private func startPulseAnimation() {
        showPulse = true
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            isAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showPulse = false
        }
    }
}
