# AcademiaFlow Project Documentation

## Core Architecture

1. Tech Stack:
- SwiftUI + SwiftData for data management
- iOS/macOS cross-platform support
- Follows SOLID principles and modern Swift practices

2. Key Models:
- Document: Core academic document model
- DocumentVersion: Version control and history
- Reference: Bibliography management  
- Note: Annotation system
- PDF: PDF document handling

3. Key Services:
- DocumentExportService (Actor): Handles document exports
- VersionManagementService (Actor): Manages document versioning

4. UI Architecture:
- NavigationSplitView with 3-column layout
- Modular view organization by feature
- Clean separation of concerns
- Strong preview support

## Core Features

1. Document Management:
- AI-powered document drafting
- Rich text editor with LaTeX/Markdown
- Custom export templates (APA, MLA)
- Version control with history
- Side-by-side version comparison

2. PDF Integration:
- Read & annotate PDFs
- Highlight and comment features
- Text/image extraction
- Side-by-side document/PDF view

3. Reference System:
- Import from PubMed, Google Scholar, Zotero
- Auto-generate citations
- Drag-and-drop bibliography
- Citation style management

4. Development Standards:
- Swift 6 features and syntax
- SOLID principles implementation
- Property wrapper best practices
- Dependency injection for testability 
- Actor-based services for thread safety
- Async/await for concurrency
- Clean modular architecture

## File Structure & Implementation

1. Models (/Models):
- Document.swift: Main document model with SwiftData
- DocumentVersion.swift: Version tracking implementation
- Note.swift: Annotation and note-taking system
- PDF.swift: PDF document handling
- Reference.swift: Bibliography reference model

2. Services (/Services):
- DocumentExportService.swift: Actor-based export handling
- VersionManagementService.swift: Version control management

3. Views Organization:
- DocumentViews/: All document-related views (List, Detail, Edit, etc)
- NoteViews/: Note management interfaces
- PDFViews/: PDF viewing and annotation
- ReferenceViews/: Bibliography management
- Shared/: Reusable components like TagEditorView

4. Key Protocols (/Protocols):
- DocumentProtocols.swift: Core document management protocols

5. Utilities:
- DocumentExporter.swift: Document export utilities

6. Architecture Patterns:
- MVVM architecture
- SwiftData for persistence
- Actor-based concurrent operations
- Protocol-oriented design

## Data Model Structure & Relationships

1. Document Model (Core):
- Basic properties: title, content, timestamps, type, tags
- Relationships: versions, notes, references (cascade deletion)
- Supports multiple document types (paper, thesis, etc)
- Includes citation styles (APA, MLA, etc)
- Uses DocumentSnapshot for actor boundary safety

2. DocumentVersion Model (Version Control):
- Tracks version number, content, timestamps
- AI integration for version summaries
- Contains diff functionality
- Bidirectional relationship with Document
- Smart version numbering system
- Version comparison capabilities

3. Note Model (Annotations):
- Unique ID, title, content, timestamp, tags
- Bidirectional relationship with Document
- Rich functionality: update, preview, isEmpty check
- Sorting capabilities (by date, title)
- Efficient snapshot system for actor boundaries

4. Reference Model (Bibliography):
- Comprehensive metadata: title, authors, DOI, URL, etc
- Multiple reference types supported
- Links to both Documents and PDFs
- Flexible initialization with optional fields

5. PDF Model (Document Management):
- File system integration (fileName, fileURL)
- Metadata: title, authors, tags
- Relationships with notes and references (cascade deletion)
- Clean initialization with optional metadata

## Services Layer

1. Document Export Service (Actor-based):
- Handles document export to PDF, Markdown, PlainText
- Uses WebKit for PDF generation
- Implements temporary file management
- Strong error handling with custom ExportError enum
- Follows actor isolation patterns with snapshots

2. Version Management Service (Actor-based):
- Handles document versioning
- Creates and manages version history
- Uses ModelContext for SwiftData persistence
- Implements version comparison functionality
- Maintains actor isolation with snapshots

3. Key Service Patterns:
- Actor-based design for thread safety
- Snapshot pattern for data transfer
- Async/await for asynchronous operations
- Clear error handling
- Dependency injection (ModelContext)

## UI Architecture

1. Navigation Structure:
- NavigationSplitView-based three-column layout
- MainView as root coordinator
- Type-safe navigation using NavigationType enum
- Modular view organization by feature (Documents/PDFs/References/Notes)

2. Document Management UI:
- DocumentListView with rich features:
  * Sorting and filtering
  * Search functionality
  * Swipe actions
  * Context menus
  * Responsive animations
- Clean separation of concerns with subviews (DocumentRow, DocumentContextMenu)
- Preview support with sample data

3. SwiftUI Best Practices:
- @Query for SwiftData integration
- @Environment for dependency injection
- Computed properties for filtered/sorted data
- Proper state management (@State, @Environment)
- Modular and reusable components
- Strong preview support

4. User Experience:
- Rich interactive features
- Consistent styling and layout
- Efficient list performance
- Intuitive navigation
- Comprehensive document management

## Code Cleanup Needed

1. Files to Delete:
- No unused Item.swift found (good!)

2. Redundant Code:
- ExportFormat definition appears in multiple places:
  * DocumentExporter.swift
  * DocumentDetailView.swift
  * Should be consolidated into a single location

3. Consolidation Needed:
- Export format handling should be centralized
- Preview implementations could be more consistent using PreviewSampleData

4. Clean Architecture Suggestions:
- Consider moving ExportFormat to a dedicated Types/Enums file
- Ensure consistent use of protocols across views
- Streamline export-related functionality into a single service