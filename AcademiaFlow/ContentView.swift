//
//  ContentView.swift
//  AcademiaFlow
//
//  Created by Shubham Tomar on 31/03/25.
//

import SwiftUI
import SwiftData

@MainActor
struct ContentView: View {
    @EnvironmentObject private var errorHandler: ErrorHandler
    
    var body: some View {
        MainView()
            .withErrorHandling()
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Document.self, PDF.self, Reference.self, Note.self, configurations: config)
        return ContentView()
            .modelContainer(container)
    } catch {
        return Text("Failed to create preview container")
    }
}
