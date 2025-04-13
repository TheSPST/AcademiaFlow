import Foundation

actor ChatService {
    private let baseURL = "http://127.0.0.1:1234/v1"
    private let timeout: TimeInterval = 30
    
    enum ChatError: Error {
        case serverError(Int)
        case noResponse
        case decodingError
        case networkTimeout
    }
    
    struct ChatMessage: Codable {
        let role: String
        let content: String
    }
    
    struct ChatRequest: Codable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Float
    }
    
    struct ChatResponse: Codable {
        let choices: [Choice]
        
        struct Choice: Codable {
            let message: ChatMessage
        }
    }
    
    func sendMessage(_ message: String, context: String) async throws -> String {
        let messages = [
            ChatMessage(role: "system", content: "You are a helpful assistant that answers questions about the following PDF content: \(context)"),
            ChatMessage(role: "user", content: message)
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
            throw ChatError.decodingError
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
