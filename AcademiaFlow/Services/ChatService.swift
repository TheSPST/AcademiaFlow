import Foundation
import SwiftData

actor ChatService {
    private let baseURL = "http://127.0.0.1:1234/v1"
    private let timeout: TimeInterval = 30
    private var rateLimitTokens: Int = 10
    private let maxTokensPerMinute = 10
    private var lastTokenRefill = Date()
    private let maxHistoryLength = 50
    private let maxContextTokens = 2000
    private let maxRetries = 3
    
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
    
    enum MessageStatus: String, Codable {
        case sending
        case sent
        case failed
        case delivered
    }
    
    private var conversationHistory: [ChatMessage] = []
    
    enum ResponseFormat: String, Codable {
        case markdown
        case plain
        case bulletPoints
    }
    
    typealias StreamHandler = @Sendable @MainActor (String) -> Void
    
    struct ChatMessage: Codable, Identifiable, Sendable {
        let id: UUID
        let role: String
        let content: String
        let timestamp: Date
        let format: ResponseFormat
        var status: MessageStatus
        var error: String?
        
        enum CodingKeys: String, CodingKey {
            case role
            case content
        }
        
        init(role: String,
             content: String,
             format: ResponseFormat = .plain,
             status: MessageStatus = .sending) {
            self.id = UUID()
            self.role = role
            self.content = content
            self.timestamp = Date()
            self.format = format
            self.status = status
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID()
            self.role = try container.decode(String.self, forKey: .role)
            self.content = try container.decode(String.self, forKey: .content)
            self.timestamp = Date()
            self.format = .plain
            self.status = .sent
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
    
    nonisolated private func executeOnMain(_ handler: StreamHandler, _ chunk: String) async {
        await MainActor.run {
            handler(chunk)
        }
    }
    
    func streamMessage(_ message: String,
                      context: String,
                      format: ResponseFormat = .plain,
                      onReceive: @escaping StreamHandler,
                      onStatus: @escaping @Sendable @MainActor (MessageStatus) -> Void) async throws {
        await onStatus(.sending)
        
        do {
            let messages = prepareMessages(userMessage: message, context: context, format: format)
            let request = prepareStreamRequest(messages: messages)
            
            for try await chunk in try await streamRequest(request) {
                await executeOnMain(onReceive, chunk)
            }
            
            await onStatus(.delivered)
            
        } catch {
            await onStatus(.failed)
            throw error
        }
    }
    
    private func prepareMessages(userMessage: String,
                               context: String,
                               format: ResponseFormat) -> [ChatMessage] {
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
    
    private func streamRequest(_ request: ChatRequest) async throws -> AsyncStream<String> {
        return AsyncStream { continuation in
            Task {
                let response = try await sendRequest(request)
                for word in response.split(separator: " ") {
                    continuation.yield(String(word) + " ")
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                continuation.finish()
            }
        }
    }
    
    private func sendRequest(_ request: ChatRequest) async throws -> String {
        print(" Chat Service: Sending request to \(baseURL)/chat/completions")
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            print(" Chat Service: Invalid API URL")
            throw URLError(.badURL)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = timeout
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            print(" Chat Service: Failed to encode request - \(error.localizedDescription)")
            throw error
        }
        
        print(" Chat Service: Awaiting response...")
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print(" Chat Service: Invalid response type")
            throw ChatError.noResponse
        }
        
        print(" Chat Service: Received response with status code \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print(" Chat Service: Server error \(httpResponse.statusCode)")
            throw ChatError.serverError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(ChatResponse.self, from: data)
            
            guard let content = decoded.choices.first?.message.content else {
                print(" Chat Service: No message content in response")
                throw ChatError.invalidResponse("No message content in response")
            }
            
            print(" Chat Service: Successfully decoded response")
            return content
        } catch let error as DecodingError {
            print(" Chat Service: Decoding error - \(error.localizedDescription)")
            throw ChatError.decodingError(error)
        } catch {
            print(" Chat Service: Unexpected error - \(error.localizedDescription)")
            throw ChatError.invalidResponse("Unexpected error: \(error.localizedDescription)")
        }
    }
    
    func sendMessageWithRetry(_ message: String,
                            context: String,
                            format: ResponseFormat = .plain) async throws -> ChatMessage {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let response = try await sendRequest(prepareStreamRequest(messages: [
                    ChatMessage(role: "system", content: "Context: \(context)", format: format),
                    ChatMessage(role: "user", content: message, format: format)
                ]))
                
                let chatMessage = ChatMessage(
                    role: "assistant",
                    content: response,
                    format: format,
                    status: .delivered
                )
                
                saveToHistory(chatMessage)
                return chatMessage
                
            } catch {
                lastError = error
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
                    continue
                }
            }
        }
        
        throw lastError ?? ChatError.networkTimeout
    }
    
    private var persistedMessages: [ChatMessage] = []
    
    private func saveToHistory(_ message: ChatMessage) {
        persistedMessages.append(message)
        if persistedMessages.count > maxHistoryLength {
            persistedMessages.removeFirst()
        }
    }
    
    private var offlineQueue: [(ChatMessage, String)] = []
    
    func queueOfflineMessage(_ message: ChatMessage, context: String) {
        offlineQueue.append((message, context))
    }
    
    func processOfflineQueue() async {
        guard !offlineQueue.isEmpty else { return }
        
        for (message, context) in offlineQueue {
            do {
                _ = try await sendMessageWithRetry(message.content, context: context, format: message.format)
            } catch {
                print("Failed to process offline message: \(error.localizedDescription)")
            }
        }
        offlineQueue.removeAll()
    }
    
    private var isConnected = true {
        didSet {
            if isConnected && !oldValue {
                Task {
                    await processOfflineQueue()
                }
            }
        }
    }
    
    func checkHealth() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else {
            print(" Chat Service: Invalid health check URL")
            isConnected = false
            throw URLError(.badURL)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 5
        
        do {
            let (_, response) = try await URLSession.shared.data(for: urlRequest)
            let isHealthy = (response as? HTTPURLResponse)?.statusCode == 200
            print(isHealthy ? " Chat Service: Running" : " Chat Service: Unhealthy response")
            isConnected = isHealthy
            return isHealthy
        } catch {
            print(" Chat Service: Connection failed - \(error.localizedDescription)")
            isConnected = false
            return false
        }
    }
    
    func sendMessage(_ message: String, context: String) async throws -> String {
        try checkRateLimit()
        print(" Chat Service: Processing message (Tokens left: \(rateLimitTokens))")
        
        let messages = [
            ChatMessage(role: "system", content: "You are a helpful assistant that answers questions about the following content: \(context)", format: .plain),
            ChatMessage(role: "user", content: message, format: .plain)
        ]
        
        let request = ChatRequest(
            model: "google_gemma-3-4b-it",
            messages: messages,
            temperature: 0.7
        )
        
        return try await sendRequest(request)
    }
    
    struct ServiceStatus {
        let isHealthy: Bool
        let activeConnections: Int
        let availableTokens: Int
        let lastResponse: Date?
    }
    
    private static var activeInstances = 0
    private let instanceId = UUID()
    
    init() {
        ChatService.activeInstances += 1
        print(" Chat Service: Instance \(instanceId) initialized (Total: \(ChatService.activeInstances))")
        Task { [weak self] in
            await self?.initializeTokenRefill()
        }
    }
    
    deinit {
        ChatService.activeInstances -= 1
        print(" Chat Service: Instance \(instanceId) deinitialized (Total: \(ChatService.activeInstances))")
    }
    
    private func initializeTokenRefill() async {
        while true {
            try? await Task.sleep(nanoseconds: 60 * 1_000_000_000) // 1 minute
            rateLimitTokens = min(rateLimitTokens + 1, maxTokensPerMinute)
            print(" Chat Service: Token refilled. Current tokens: \(rateLimitTokens)")
        }
    }
    
    private func checkRateLimit() throws {
        guard rateLimitTokens > 0 else {
            throw ChatError.networkTimeout
        }
        rateLimitTokens -= 1
    }
    
    func getServiceStatus() async -> ServiceStatus {
        return ServiceStatus(
            isHealthy: true,
            activeConnections: ChatService.activeInstances,
            availableTokens: rateLimitTokens,
            lastResponse: lastTokenRefill
        )
    }
}

extension ChatService {
    private static let instanceLock = NSLock()
    
    private static func incrementInstances() -> Int {
        instanceLock.lock()
        defer { instanceLock.unlock() }
        activeInstances += 1
        return activeInstances
    }
    
    private static func decrementInstances() -> Int {
        instanceLock.lock()
        defer { instanceLock.unlock() }
        activeInstances -= 1
        return activeInstances
    }
}

extension ChatService {
    private func logServiceMetrics(request: ChatRequest) {
        print("""
        Chat Service Metrics:
        - Active Instances: \(ChatService.activeInstances)
        - Available Tokens: \(rateLimitTokens)
        - Message Length: \(request.messages.reduce(0) { $0 + $1.content.count })
        - Timestamp: \(Date())
        """)
    }
}
