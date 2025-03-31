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
    var body: some View {
        #if os(iOS)
        NavigationStack {
            MainView()
        }
        #else
        MainView()
        #endif
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
