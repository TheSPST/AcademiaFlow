
import SwiftUI

private struct ChatServiceKey: EnvironmentKey {
    static let defaultValue: ChatService? = nil // Or a default instance if appropriate, but nil is safer for services
}

extension EnvironmentValues {
    var chatService: ChatService? {
        get { self[ChatServiceKey.self] }
        set { self[ChatServiceKey.self] = newValue }
    }
}

