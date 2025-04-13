import Foundation
import SwiftData

actor ChatService {
    private let baseURL = "http://127.0.0.1:1234/v1"
    private let timeout: TimeInterval = 30
    
    enum ChatError: Error, LocalizedError {
        case serverError(Int)
        case noResponse
        case decodingError(DecodingError)
        case networkTimeout
        case invalidResponse(String)
        
        var errorDescription: String? {
            switch self {
            case .serverError(let code):
                return "Server error: \(code)"
            case .noResponse:
                return "No response from server"
            case .decodingError(let error):
                switch error {
                case .dataCorrupted(let context):
                    return "Data corrupted: \(context.debugDescription)"
                case .keyNotFound(let key, let context):
                    return "Key '\(key.stringValue)' not found: \(context.debugDescription)"
                case .typeMismatch(let type, let context):
                    return "Type '\(type)' mismatch: \(context.debugDescription)"
                case .valueNotFound(let type, let context):
                    return "Value of type '\(type)' not found: \(context.debugDescription)"
                @unknown default:
                    return "Unknown decoding error: \(error.localizedDescription)"
                }
            case .networkTimeout:
                return "Network request timed out"
            case .invalidResponse(let details):
                return "Invalid response: \(details)"
            }
        }
    }
    
    // ADD: Chat history management
    private var conversationHistory: [ChatMessage] = []
    private let maxHistoryLength = 50
    private let maxContextTokens = 2000
    
    // ADD: Formatting options
    enum ResponseFormat: String, Codable {
        case markdown
        case plain
        case bulletPoints
    }
    
    // FIX: Make StreamHandler Sendable
    typealias StreamHandler = @Sendable @MainActor (String) -> Void
    
    // ADD: Stream handlers
    
    // FIX: Enhanced chat message with proper Codable conformance
    struct ChatMessage: Codable, Identifiable {
        let id: UUID
        let role: String
        let content: String
        let timestamp: Date
        let format: ResponseFormat
        
        enum CodingKeys: String, CodingKey {
            case role
            case content
        }
        
        init(role: String, content: String, format: ResponseFormat = .plain) {
            self.id = UUID()
            self.role = role
            self.content = content
            self.timestamp = Date()
            self.format = format
        }
        
        // FIX: Decode only role and content from API
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID()
            self.role = try container.decode(String.self, forKey: .role)
            self.content = try container.decode(String.self, forKey: .content)
            self.timestamp = Date()
            self.format = .plain
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(role, forKey: .role)
            try container.encode(content, forKey: .content)
        }
    }
    
    struct ChatRequest: Codable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Float
    }
    
    struct ChatResponse: Codable {
        let id: String
        let object: String
        let created: Int
        let model: String
        let choices: [Choice]
        let usage: Usage
        let stats: [String: String]
        let system_fingerprint: String
        
        struct Choice: Codable {
            let index: Int
            let logprobs: String?
            let finish_reason: String
            let message: ChatMessage
        }
        
        struct Usage: Codable {
            let prompt_tokens: Int
            let completion_tokens: Int
            let total_tokens: Int
        }
    }
    
    // FIX: Add proper async/await handling for streaming
    // ADD: Nonisolated method to ensure closure execution on main actor
    nonisolated private func executeOnMain(_ handler: StreamHandler, _ chunk: String) async {
        await MainActor.run {
            handler(chunk)
        }
    }
    
    // FIX: Properly handle actor isolation for streaming
    func streamMessage(_ message: String,
                      context: String,
                      format: ResponseFormat = .plain,
                      onReceive: @escaping StreamHandler) async throws {
        let messages = prepareMessages(userMessage: message, context: context, format: format)
        let request = prepareStreamRequest(messages: messages)
        
        for try await chunk in try await streamRequest(request) {
            // Execute handler on main actor
            await executeOnMain(onReceive, chunk)
        }
    }
    
    // ADD: Smart context management
    private func prepareMessages(userMessage: String,
                               context: String,
                               format: ResponseFormat) -> [ChatMessage] {
        // Trim history if too long
        if conversationHistory.count > maxHistoryLength {
            conversationHistory.removeFirst(conversationHistory.count - maxHistoryLength)
        }
        
        let systemPrompt: String
        switch format {
        case .markdown:
            systemPrompt = "You are a helpful assistant that answers in Markdown format about: \(context)"
        case .bulletPoints:
            systemPrompt = "You are a helpful assistant that answers in bullet points about: \(context)"
        case .plain:
            systemPrompt = "You are a helpful assistant that answers questions about: \(context)"
        }
        
        let newMessage = ChatMessage(role: "user",
                                   content: userMessage,
                                   format: format)
        conversationHistory.append(newMessage)
        
        return [
            ChatMessage(role: "system", content: systemPrompt, format: format)
        ] + conversationHistory
    }
    
    private func prepareStreamRequest(messages: [ChatMessage]) -> ChatRequest {
        return ChatRequest(
            model: "google_gemma-3-4b-it",
            messages: messages,
            temperature: 0.7
        )
    }
    
    // ADD: Conversation summarization
    func summarizeConversation() async throws -> String {
        let summaryPrompt = ChatMessage(
            role: "system",
            content: "Summarize the key points of this conversation:",
            format: .bulletPoints
        )
        
        let messages = [summaryPrompt] + conversationHistory
        let request = ChatRequest(
            model: "google_gemma-3-4b-it",
            messages: messages,
            temperature: 0.7
        )
        
        return try await sendRequest(request)
    }
    
    // HELPER: Stream request implementation
    private func streamRequest(_ request: ChatRequest) async throws -> AsyncStream<String> {
        // Implementation for streaming responses
        return AsyncStream { continuation in
            Task {
                // Simulate streaming for now
                // In real implementation, would use Server-Sent Events or WebSocket
                let response = try await sendRequest(request)
                for word in response.split(separator: " ") {
                    continuation.yield(String(word) + " ")
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
                }
                continuation.finish()
            }
        }
    }
    
    // HELPER: Send request implementation
    private func sendRequest(_ request: ChatRequest) async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw URLError(.badURL)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = timeout
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ChatError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        // Debug: Print raw JSON for debugging
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Raw JSON response:", jsonString)
        }
        #endif
        
        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(ChatResponse.self, from: data)
            
            guard let content = decoded.choices.first?.message.content else {
                throw ChatError.invalidResponse("No message content in response")
            }
            
            return content
        } catch let error as DecodingError {
            throw ChatError.decodingError(error)
        } catch {
            throw ChatError.invalidResponse("Unexpected error: \(error.localizedDescription)")
        }
    }
    
    func sendMessage(_ message: String, context: String) async throws -> String {
        let messages = [
            ChatMessage(role: "system", content: "You are a helpful assistant that answers questions about the following PDF content: \(context)", format: .plain),
            ChatMessage(role: "user", content: message, format: .plain)
        ]
        
        let request = ChatRequest(
            model: "google_gemma-3-4b-it",
            messages: messages,
            temperature: 0.7
        )
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw URLError(.badURL)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = timeout
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.noResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ChatError.serverError(httpResponse.statusCode)
        }
        
        do {
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            return decoded.choices.first?.message.content ?? "No response"
        } catch {
            throw ChatError.decodingError(DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: error.localizedDescription)))
        }
    }
    
    func checkHealth() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else {
            throw URLError(.badURL)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 5
        
        do {
            let (_, response) = try await URLSession.shared.data(for: urlRequest)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
