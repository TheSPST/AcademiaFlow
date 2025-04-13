//
//  DocumentOutlineView.swift
//  AcademiaFlow
//
//  Created by Shubham Tomar on 31/03/25.
//

import SwiftUI
import SwiftData

struct DocumentOutlineView: View {
    let document: Document
    @State private var expandedSections: Set<String> = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderSection()
                DocumentStatistics(document: document)
                OutlineContent(document: document, expandedSections: $expandedSections)
            }
            .padding()
        }
    }
}

private struct HeaderSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Document Outline")
                .font(.title2)
                .bold()
            Divider()
        }
    }
}

private struct DocumentStatistics: View {
    let document: Document
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                StatRow(label: "References", value: "\(document.references.count)")
                StatRow(label: "Notes", value: "\(document.notes.count)")
                StatRow(label: "Versions", value: "\(document.versions.count)")
                StatRow(label: "Tags", value: "\(document.tags.count)")
                StatRow(label: "Last Updated", value: document.updatedAt.formatted())
            }
            Divider()
        }
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }
}

private struct OutlineContent: View {
    let document: Document
    @Binding var expandedSections: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            OutlineSection(
                title: "References",
                isExpanded: expandedSections.contains("references"),
                onToggle: { toggleSection("references") }
            ) {
                ForEach(document.references) { reference in
                    Text("• \(reference.title)")
                        .padding(.leading)
                }
            }
            
            OutlineSection(
                title: "Notes",
                isExpanded: expandedSections.contains("notes"),
                onToggle: { toggleSection("notes") }
            ) {
                ForEach(document.notes) { note in
                    Text("• \(note.title)")
                        .padding(.leading)
                }
            }
            
            OutlineSection(
                title: "Versions",
                isExpanded: expandedSections.contains("versions"),
                onToggle: { toggleSection("versions") }
            ) {
                ForEach(document.versions, id: \.versionNumber) { version in
                    Text("• Version \(version.versionNumber)")
                        .padding(.leading)
                }
            }
            
            if !document.tags.isEmpty {
                OutlineSection(
                    title: "Tags",
                    isExpanded: expandedSections.contains("tags"),
                    onToggle: { toggleSection("tags") }
                ) {
                    FlowLayout(spacing: 8) {
                        ForEach(document.tags, id: \.self) { tag in
                            TagView(tag: tag, onRemove: {
                                
                            })
                        }
                    }
                    .padding(.leading)
                }
            }
        }
    }
    
    private func toggleSection(_ section: String) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }
}

private struct OutlineSection<Content: View>: View {
    let title: String
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    Text(title)
                        .font(.headline)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                content()
            }
        }
    }
}
