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
        }
    }
}
