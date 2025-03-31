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
    let modelContainer: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                Document.self,
                DocumentVersion.self,
                Reference.self,
                Note.self,
                PDF.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        
        #if os(macOS)
        Settings {
            Text("Settings")
        }
        #endif
    }
}
