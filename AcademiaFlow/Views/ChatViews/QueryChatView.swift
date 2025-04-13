import SwiftUI
import SwiftData

@available(macOS 14.0, *)
@MainActor
struct QueryChatView: View {
    @Binding var isPresented: Bool
    @State private var queryText = ""
    @State private var results: [QueryResult] = []
    @State private var isLoading = false
    @State private var selectedItem: Any?
    @State private var showingItemDetail = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // ADD: Navigation bindings
    @Binding var selectedNavigation: NavigationType?
    @Binding var selectedDocument: Document?
    @Binding var selectedPDF: PDF?
    @Binding var selectedNote: Note?
    @Binding var selectedReference: Reference?
    
    let chatService = ChatService()
    
    // ADD: Make QueryResult properly handle SwiftData identifiers
    struct QueryResult: Identifiable, Codable {
        let id: UUID
        let type: String
        let summary: String
        
        private let documentIds: [PersistentIdentifier]
        private let pdfIds: [PersistentIdentifier]
        private let noteIds: [PersistentIdentifier]
        private let referenceIds: [PersistentIdentifier]
        
        func items(in context: ModelContext) -> [AnyHashable] {
            var results: [AnyHashable] = []
            
            if !documentIds.isEmpty {
                var descriptor = FetchDescriptor<Document>()
                descriptor.predicate = #Predicate<Document> { document in
                    self.documentIds.contains(document.persistentModelID)
                }
                if let documents = try? context.fetch(descriptor) {
                    results.append(contentsOf: documents)
                }
            }
            
            if !pdfIds.isEmpty {
                var descriptor = FetchDescriptor<PDF>()
                descriptor.predicate = #Predicate<PDF> { pdf in
                    self.pdfIds.contains(pdf.persistentModelID)
                }
                if let pdfs = try? context.fetch(descriptor) {
                    results.append(contentsOf: pdfs)
                }
            }
            
            if !noteIds.isEmpty {
                var descriptor = FetchDescriptor<Note>()
                descriptor.predicate = #Predicate<Note> { note in
                    self.noteIds.contains(note.persistentModelID)
                }
                if let notes = try? context.fetch(descriptor) {
                    results.append(contentsOf: notes)
                }
            }
            
            if !referenceIds.isEmpty {
                var descriptor = FetchDescriptor<Reference>()
                descriptor.predicate = #Predicate<Reference> { reference in
                    self.referenceIds.contains(reference.persistentModelID)
                }
                if let references = try? context.fetch(descriptor) {
                    results.append(contentsOf: references)
                }
            }
            
            return results
        }
        
        init(type: String, items: [Any], summary: String) {
            self.id = UUID()
            self.type = type
            self.summary = summary
            
            // FIX: Store actual PersistentIdentifiers
            self.documentIds = items.compactMap { ($0 as? Document)?.persistentModelID }
            self.pdfIds = items.compactMap { ($0 as? PDF)?.persistentModelID }
            self.noteIds = items.compactMap { ($0 as? Note)?.persistentModelID }
            self.referenceIds = items.compactMap { ($0 as? Reference)?.persistentModelID }
        }
    }
    
    let suggestedQueries = [
        "Show me recent documents",
        "Find PDFs with annotations",
        "List my research references",
        "Show notes from last week",
        "Find documents tagged 'research'"
    ]
    
    // ADD: Search history persistence
    @AppStorage("recentQueries") private var recentQueriesData: Data = Data()
    @State private var recentQueries: [String] = []
    
    // ADD: Save current state
    @AppStorage("lastResults") private var lastResultsData: Data = Data()
    
    // ADD: Current section selection for persistence
    @SceneStorage("selectedQuerySection") private var selectedSection: String?
    
    // ADD: Search filters
    @State private var selectedFilters: Set<String> = []
    @State private var dateRange: DateRange = .allTime
    
    enum DateRange: String, CaseIterable {
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case allTime = "All Time"
        
        var date: Date {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .today:
                return calendar.startOfDay(for: now)
            case .thisWeek:
                return calendar.date(byAdding: .day, value: -7, to: now) ?? now
            case .thisMonth:
                return calendar.date(byAdding: .month, value: -1, to: now) ?? now
            case .allTime:
                return .distantPast
            }
        }
    }
    
    // ADD: Connection status
    @State private var connectionStatus: ConnectionStatus = .checking
    
    enum ConnectionStatus {
        case checking
        case connected
        case disconnected
        
        var icon: String {
            switch self {
            case .checking: return "clock"
            case .connected: return "checkmark.circle.fill"
            case .disconnected: return "exclamationmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .checking: return .gray
            case .connected: return .green
            case .disconnected: return .red
            }
        }
    }
    
    // ADD: Service status
    @State private var serviceStatus: ChatService.ServiceStatus?
    @State private var showingDebugInfo = false
    
    private var statusColor: Color {
        guard let status = serviceStatus else { return .gray }
        if !status.isHealthy { return .red }
        if status.availableTokens == 0 { return .orange }
        return .green
    }
    
    private func saveRecentQueries() {
        do {
            let data = try JSONEncoder().encode(recentQueries)
            recentQueriesData = data
        } catch {
            print("Failed to save recent queries:", error)
        }
    }
    
    private func loadRecentQueries() {
        do {
            recentQueries = try JSONDecoder().decode([String].self, from: recentQueriesData)
        } catch {
            print("Failed to load recent queries:", error)
            recentQueries = []
        }
    }
    
    private func addToRecentQueries(_ query: String) {
        // Keep only unique queries and limit to last 10
        recentQueries.removeAll { $0 == query }
        recentQueries.insert(query, at: 0)
        if recentQueries.count > 10 {
            recentQueries.removeLast()
        }
        saveRecentQueries()
    }
    
    private func saveCurrentState() {
        do {
            let data = try JSONEncoder().encode(results)
            lastResultsData = data
        } catch {
            print("Failed to save current state:", error)
        }
    }
    
    private func loadLastState() {
        do {
            results = try JSONDecoder().decode([QueryResult].self, from: lastResultsData)
        } catch {
            print("Failed to load last state:", error)
            results = []
        }
    }
    
    private func navigateToItem(_ item: Any) {
        switch item {
        case let document as Document:
            selectedNavigation = .documents
            selectedDocument = document
            isPresented = false
            
        case let pdf as PDF:
            selectedNavigation = .pdfs
            selectedPDF = pdf
            isPresented = false
            
        case let note as Note:
            selectedNavigation = .notes
            selectedNote = note
            isPresented = false
            
        case let reference as Reference:
            selectedNavigation = .references
            selectedReference = reference
            isPresented = false
            
        default:
            break
        }
    }
    
    private func updateServiceStatus() async {
        serviceStatus = await chatService.getServiceStatus()
        
        Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(5))
                    if !Task.isCancelled {
                        serviceStatus = await chatService.getServiceStatus()
                    }
                } catch {
                    print("Status update error:", error)
                }
            }
        }
    }
    
    private func executeQuery() {
        guard connectionStatus == .connected else {
            // Show connection error
            return
        }
        
        isLoading = true
        addToRecentQueries(queryText)
        
        Task {
            do {
                results = []  // Clear previous results
                
                if queryText.contains("document") {
                    try await handleDocumentQuery()
                }
                
                if queryText.contains("pdf") || queryText.contains("pdfs") {
                    try await handlePDFQuery()
                }
                
                if queryText.contains("note") || queryText.contains("notes") {
                    try await handleNoteQuery()
                }
                
                if queryText.contains("reference") || queryText.contains("references") {
                    try await handleReferenceQuery()
                }
                
            } catch {
                print("Query error:", error)
                // TODO: Show error to user
            }
            
            isLoading = false
            queryText = ""
            saveCurrentState()
        }
    }
    
    private func handleDocumentQuery() async throws {
        var descriptor = FetchDescriptor<Document>()
        
        // Set sort and limit for recent documents
        if queryText.contains("recent") || queryText.contains("newest") {
            descriptor.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]
            descriptor.fetchLimit = 5
        }

        // Create date filter
        if dateRange != .allTime {
            let compareDate = dateRange.date
            descriptor = FetchDescriptor<Document>(predicate: #Predicate<Document> { document in
                document.updatedAt >= compareDate
            })
        }
        
        // Add tag filter if needed
        if queryText.contains("tag") {
            let tagPredicate = #Predicate<Document> { document in
                !document.tags.isEmpty
            }
            descriptor.predicate = tagPredicate
        }
        
        let documents = try modelContext.fetch(descriptor)
        let summary = try await generateSummary(for: documents, type: "documents")
        results.append(QueryResult(type: "Documents", items: documents, summary: summary))
    }
    
    private func handlePDFQuery() async throws {
        var descriptor = FetchDescriptor<PDF>()
        
        if dateRange != .allTime {
            let compareDate = dateRange.date
            descriptor = FetchDescriptor<PDF>(predicate: #Predicate<PDF> { pdf in
                pdf.addedAt >= compareDate
            })
        }
        
        let pdfs = try modelContext.fetch(descriptor)
        let summary = try await generateSummary(for: pdfs, type: "PDFs")
        results.append(QueryResult(type: "PDFs", items: pdfs, summary: summary))
    }
    
    private func handleNoteQuery() async throws {
        var descriptor = FetchDescriptor<Note>()
        
        if dateRange != .allTime {
            let compareDate = dateRange.date
            descriptor = FetchDescriptor<Note>(predicate: #Predicate<Note> { note in
                note.timestamp >= compareDate
            })
        }
        
        let notes = try modelContext.fetch(descriptor)
        let summary = try await generateSummary(for: notes, type: "notes")
        results.append(QueryResult(type: "Notes", items: notes, summary: summary))
    }
    
    private func handleReferenceQuery() async throws {
        var descriptor = FetchDescriptor<Reference>()
        
        if dateRange != .allTime {
            let compareDate = dateRange.date
            descriptor = FetchDescriptor<Reference>(predicate: #Predicate<Reference> { reference in
                reference.addedAt >= compareDate
            })
        }
        
        let references = try modelContext.fetch(descriptor)
        let summary = try await generateSummary(for: references, type: "references")
        results.append(QueryResult(type: "References", items: references, summary: summary))
    }
    
    private func generateSummary(for items: [Any], type: String) async throws -> String {
        let context = "Summary request for \(items.count) \(type)"
        return try await chatService.sendMessage("Summarize these \(type)", context: context)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Ask about your documents")
                    .font(.headline)
                
                Spacer()
                
                // ADD: Connection status indicator
                Label("", systemImage: connectionStatus.icon)
                    .foregroundColor(connectionStatus.color)
                    .help(connectionStatus == .connected ? "Connected to chat service" : "Chat service unavailable")
                
                // ADD: Debug button
                Button(action: { showingDebugInfo.toggle() }) {
                    Label("", systemImage: "info.circle")
                        .foregroundStyle(statusColor)
                }
                .popover(isPresented: $showingDebugInfo) {
                    ServiceDebugView(status: serviceStatus)
                }
                .help("Service Status")
                
                HStack(spacing: 16) {
                    Button(action: { selectedNavigation = .documents }) {
                        Image(systemName: "doc.text")
                    }
                    .help("Go to Documents")
                    
                    Button(action: { selectedNavigation = .pdfs }) {
                        Image(systemName: "doc.richtext")
                    }
                    .help("Go to PDFs")
                    
                    Button(action: { withAnimation { isPresented = false }}) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            
            // ADD: Filters section
            if !results.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DateRange.allCases, id: \.rawValue) { range in
                            FilterButton(
                                title: range.rawValue,
                                isSelected: dateRange == range
                            ) {
                                dateRange = range
                                executeQuery()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if results.isEmpty {
                        // ADD: Recent queries section
                        if !recentQueries.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recent Searches")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(recentQueries, id: \.self) { query in
                                            Button(action: {
                                                queryText = query
                                                executeQuery()
                                            }) {
                                                HStack {
                                                    Text(query)
                                                    Image(systemName: "arrow.counterclockwise")
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(.blue.opacity(0.1))
                                                .clipShape(Capsule())
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Try asking about:")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(suggestedQueries, id: \.self) { query in
                                        SuggestionButton(text: query) {
                                            queryText = query
                                            executeQuery()
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    ForEach(results) { result in
                        QueryResultView(result: result, onSelect: navigateToItem)
                    }
                }
                .padding()
            }
            
            if !queryText.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(dynamicSuggestions, id: \.self) { suggestion in
                            SuggestionButton(text: suggestion) {
                                queryText = suggestion
                                executeQuery()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            HStack {
                TextField("Ask something...", text: $queryText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(executeQuery)
                
                Button(action: executeQuery) {
                    Group {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "magnifyingglass.circle.fill")
                                .font(.title2)
                        }
                    }
                    .frame(width: 24, height: 24)
                }
                .disabled(queryText.isEmpty || isLoading)
            }
            .padding()
        }
        .onAppear {
            loadRecentQueries()
            loadLastState()
        }
        .task {
            await checkServiceConnection()
            await updateServiceStatus()
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
    }
    
    private var dynamicSuggestions: [String] {
        let input = queryText.lowercased()
        
        if input.contains("document") {
            return [
                "Show newest documents",
                "Find documents with tag",
                "List document versions"
            ]
        } else if input.contains("pdf") {
            return [
                "Show annotated PDFs",
                "Find PDFs with notes",
                "List PDF references"
            ]
        } else if input.contains("note") {
            return [
                "Show recent notes",
                "Find notes with tag",
                "List document notes"
            ]
        } else if input.contains("reference") {
            return [
                "Show citation references",
                "Find references by author",
                "List document references"
            ]
        }
        
        return []
    }
    
    private func checkServiceConnection() async {
        connectionStatus = .checking
        do {
            if try await chatService.checkHealth() {
                connectionStatus = .connected
            } else {
                connectionStatus = .disconnected
            }
        } catch {
            connectionStatus = .disconnected
        }
    }
    
    // ADD: Filter button component
    struct FilterButton: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isSelected ? .blue : .blue.opacity(0.1))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .clipShape(Capsule())
            }
        }
    }
    
    struct SuggestionButton: View {
        let text: String
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
    
    // UPDATE: QueryResultView to use ModelContext properly
    struct QueryResultView: View {
        let result: QueryChatView.QueryResult
        let onSelect: (Any) -> Void
        @Environment(\.modelContext) private var modelContext
        @State private var showingShareSheet = false
        @State private var copiedText: String?
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(result.type, systemImage: iconForType(result.type))
                        .font(.headline)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: copyToClipboard) {
                            Image(systemName: copiedText != nil ? "checkmark.circle.fill" : "doc.on.doc")
                        }
                        .help("Copy summary")
                        
                        Button(action: { showingShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .help("Share")
                        
                        Menu {
                            Button("Export Results") { /* Implementation */ }
                            Button("Filter Results") { /* Implementation */ }
                            Button("Sort Results") { /* Implementation */ }
                            Divider()
                            Button("Export as PDF") { /* Implementation */ }
                            Button("Add to References") { /* Implementation */ }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                
                HStack(spacing: 8) {
                    Text("Found \(result.items(in: modelContext).count) items")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    ProgressView(value: Double(result.items(in: modelContext).count), total: 100)
                        .progressViewStyle(.linear)
                        .frame(width: 60)
                }
                
                Text(result.summary)
                    .font(.body)
                    .padding(.vertical, 4)
                    .overlay(alignment: .topTrailing) {
                        if copiedText != nil {
                            Text("Copied!")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .padding(4)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .transition(.scale.combined(with: .opacity))
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation {
                                            copiedText = nil
                                        }
                                    }
                                }
                        }
                    }
                
                let items = result.items(in: modelContext)
                if !items.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(0..<min(5, items.count), id: \.self) { index in
                                NavigationPreviewCard(
                                    item: items[index],
                                    onSelect: onSelect
                                )
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .sheet(isPresented: $showingShareSheet) {
                if #available(macOS 14.0, *) {
                    ShareLink(
                        item: result.summary,
                        preview: SharePreview(
                            result.type,
                            image: "doc"
                        )
                    )
                }
            }
        }
        
        private func copyToClipboard() {
#if os(iOS)
            UIPasteboard.general.string = result.summary
#else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result.summary, forType: .string)
#endif
            
            withAnimation {
                copiedText = result.summary
            }
        }
        
        private func iconForType(_ type: String) -> String {
            switch type {
            case "Documents": return "doc.text"
            case "PDFs": return "doc.richtext"
            case "Notes": return "note.text"
            case "References": return "books.vertical"
            default: return "questionmark.circle"
            }
        }
    }
    
    struct NavigationPreviewCard: View {
        let item: AnyHashable
        @State private var isHovered = false
        let onSelect: (Any) -> Void
        
        var body: some View {
            Button(action: { onSelect(item) }) {
                VStack(alignment: .leading) {
                    Group {
                        if let document = item as? Document {
                            Label(document.title, systemImage: "doc.text")
                        } else if let pdf = item as? PDF {
                            Label(pdf.fileName, systemImage: "doc.richtext")
                        } else if let note = item as? Note {
                            Label(note.title, systemImage: "note.text")
                        } else if let reference = item as? Reference {
                            Label(reference.title, systemImage: "books.vertical")
                        }
                    }
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                    
                    if isHovered {
                        Text("Click to open")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 120)
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.2), value: isHovered)
        }
    }
    
    // ADD: Debug view for service status
    struct ServiceDebugView: View {
        let status: ChatService.ServiceStatus?
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Chat Service Status")
                    .font(.headline)
                
                if let status = status {
                    Label(
                        status.isHealthy ? "Healthy" : "Unhealthy",
                        systemImage: status.isHealthy ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundStyle(status.isHealthy ? Color.green : Color.red)
                    
                    Divider()
                    
                    VStack(alignment: .leading) {
                        InfoRow(
                            title: "Active Connections",
                            value: "\(status.activeConnections)"
                        )
                        InfoRow(
                            title: "Available Tokens",
                            value: "\(status.availableTokens)"
                        )
                        if let lastResponse = status.lastResponse {
                            InfoRow(
                                title: "Last Response",
                                value: timeAgoString(from: lastResponse)
                            )
                        }
                    }
                } else {
                    Text("Status Unavailable")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(width: 250)
        }
        
        private func timeAgoString(from date: Date) -> String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: Date())
        }
    }
    
    struct InfoRow: View {
        let title: String
        let value: String
        
        var body: some View {
            HStack {
                Text(title)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .monospacedDigit()
            }
            .font(.callout)
        }
    }
}
