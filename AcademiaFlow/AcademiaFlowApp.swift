//
//  AcademiaFlowApp.swift
//  AcademiaFlow
//
//  Created by Shubham Tomar on 31/03/25.
//

import SwiftUI
import SwiftData

@main
struct AcademiaFlowApp: App {
    @StateObject private var errorHandler = ErrorHandler()
    // CHANGE: Instantiate ChatService as a regular constant
    private let chatService = ChatService() 

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [
                    Document.self,
                    PDF.self,
                    Reference.self,
                    Note.self,
                    StoredAnnotation.self
                ])
                .environmentObject(errorHandler)
                // CHANGE: Inject ChatService using custom environment key
                .environment(\.chatService, chatService)
        }
    }
}
