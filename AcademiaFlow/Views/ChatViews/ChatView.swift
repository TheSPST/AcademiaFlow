import SwiftUI

@MainActor
struct ChatView: View {
    @State private var messageText = ""
    @State private var messages: [ChatService.ChatMessage] = []
    @State private var isLoading = false
    @State private var streamingText = ""
    @State private var error: String?
    
    let chatService = ChatService()
    let context: String
    
    var body: some View {
        VStack {
            if let error = error {
                Text(error)
                    .foregroundStyle(.red)
                    .padding()
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                    if !streamingText.isEmpty {
                        MessageBubble(
                            message: .init(
                                role: "assistant",
                                content: streamingText
                            )
                        )
                    }
                }
                .padding()
            }
            
            HStack {
                TextField("Message...", text: $messageText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)
                
                Button(action: sendMessage) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                    }
                }
                .disabled(messageText.isEmpty || isLoading)
            }
            .padding()
        }
        .task {
            do {
                // Check chat service health on view appear
                if try await chatService.checkHealth() == false {
                    error = "Chat service is not available"
                }
            } catch {
                self.error = "Failed to connect to chat service"
            }
        }
    }
    
    private func sendMessage() {
        let message = messageText
        messageText = ""
        isLoading = true
        error = nil
        
        Task {
            do {
                try await chatService.streamMessage(
                    message,
                    context: context,
                    format: .markdown
                ) { @MainActor chunk in
                    streamingText += chunk
                }
                
                messages.append(
                    .init(
                        role: "assistant",
                        content: streamingText,
                        format: .markdown
                    )
                )
                streamingText = ""
            } catch let chatError as ChatService.ChatError {
                // Use the improved error descriptions
                self.error = chatError.errorDescription
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct MessageBubble: View {
    let message: ChatService.ChatMessage
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer()
            }
            
            Text(message.content)
                .padding()
                .background(
                    message.role == "user"
                    ? Color.blue.opacity(0.2)
                    : Color.gray.opacity(0.2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            if message.role == "assistant" {
                Spacer()
            }
        }
    }
}
