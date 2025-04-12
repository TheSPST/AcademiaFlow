import SwiftUI
import SwiftData

@MainActor
struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.timestamp, order: .reverse) private var notes: [Note]
    @Binding var selectedNote: Note?
    @State private var searchText = ""
    @State private var sortOption: SortOption = .modified
    
    var body: some View {
        VStack {
            GenericListView(
                searchText: $searchText,
                sortOption: $sortOption,
                items: notes,
                title: "Notes",
                rowContent: makeNoteRow,
                onDelete: deleteNote,
                onDuplicate: duplicateNote
            )
            .toolbar {
                ToolbarItem {
                    Button(action: createNewNote) {
                        Label("Add Note", systemImage: "plus")
                    }
                }
            }
        }
        .onChange(of: notes) { _, newNotes in
            handleNotesChange(newNotes)
        }
        .onAppear {
            handleInitialSetup()
        }
    }
    
    private func makeNoteRow(_ note: Note) -> some View {
        Button {
            selectedNote = note
        } label: {
            ItemRowView(
                item: note,
                subtitle: String(note.content.prefix(100)),
                metadata: "Created: \(note.timestamp.formatted())"
            )
        }
        .buttonStyle(.plain)
        .background(selectedNote?.id == note.id ? Color.accentColor.opacity(0.1) : Color.clear)
    }
    
    private func handleNotesChange(_ newNotes: [Note]) {
        if selectedNote == nil && !newNotes.isEmpty {
            selectedNote = newNotes[0]
        }
    }
    
    private func handleInitialSetup() {
        if selectedNote == nil && !notes.isEmpty {
            selectedNote = notes[0]
        }
        if notes.isEmpty {
            addSampleNotes()
        }
    }
    
    private func createNewNote() {
        let newNote = Note(
            title: "New Note",
            content: "",
            tags: []
        )
        modelContext.insert(newNote)
    }
    
    private func deleteNote(_ note: Note) {
        modelContext.delete(note)
    }
    
    private func duplicateNote(_ note: Note) {
        let newNote = Note(
            title: note.title + " (Copy)",
            content: note.content,
            tags: note.tags,
            pageNumber: note.pageNumber
        )
        modelContext.insert(newNote)
    }
    
    private func addSampleNotes() {
        addResearchNote()
        addMeetingNote()
    }
    
    private func addResearchNote() {
        let note = Note(
            title: "Research Ideas",
            content: """
                1. Investigate SwiftUI performance optimizations
                2. Study async/await patterns
                3. Explore actor isolation strategies
                """,
            tags: ["research", "swift", "performance"]
        )
        modelContext.insert(note)
    }
    
    private func addMeetingNote() {
        let note = Note(
            title: "Meeting Notes",
            content: """
                Discussed project architecture and timeline.
                Key points:
                - Use MVVM pattern
                - Implement proper error handling
                - Focus on modularity
                """,
            tags: ["meeting", "architecture"]
        )
        modelContext.insert(note)
    }
}

#if DEBUG
struct NoteListView_Previews: PreviewProvider {
    static var previews: some View {
        NoteListView(selectedNote: .constant(nil))
            .modelContainer(PreviewSampleData.shared.container)
    }
}
#endif
