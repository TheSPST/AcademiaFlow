# AcademiaFlow

A SwiftUI + SwiftData academic writing and research management application.

## Project Status

### Core Architecture
- ✅ SwiftUI + SwiftData implementation
- ✅ Base navigation structure using NavigationSplitView
- ✅ Core data models defined
- ✅ Basic CRUD operations structure
- ✅ Cross-platform (iOS/macOS) support

### Data Models
All core models implemented with SwiftData:
- ✅ Document
  - Properties: title, content, type, tags, timestamps
  - Supports: version history, notes, references
  - Document types: paper, thesis, literature review, abstract, outline
  
- ✅ DocumentVersion
  - Version control system
  - AI summary support
  - Change tracking
  
- ✅ PDF
  - File management
  - Metadata handling
  - Linked notes and references
  
- ✅ Reference
  - Multiple types (article, book, conference, etc.)
  - Complete academic metadata
  - DOI and URL support
  
- ✅ Note
  - Basic structure implemented
  - Linking with documents and PDFs

### Views Implementation Status
1. Navigation
   - ✅ Main navigation structure
   - ✅ Section navigation (Documents, PDFs, References, Notes)

2. Document Management
   - ✅ Basic document list view
   - 🚧 Document editing interface
   - 🚧 Version history viewer
   - 🚧 Template system

3. PDF Integration
   - ✅ Basic PDF list view
   - 🚧 PDF viewer
   - 🚧 Annotation system
   - 🚧 Text extraction

4. Reference Management
   - ✅ Basic reference list view
   - 🚧 Reference editor
   - 🚧 Citation generator
   - 🚧 Bibliography builder

5. Note Taking
   - ✅ Basic note list view
   - 🚧 Note editor
   - 🚧 Tag system
   - 🚧 Search functionality

### Planned Features
1. AI Integration
   - 🚧 AI-powered drafting
   - 🚧 Grammar checking
   - 🚧 Research assistance
   - 🚧 Version summary generation

2. Advanced Features
   - 🚧 LaTeX/Markdown support
   - 🚧 Export templates
   - 🚧 Citation style formatting
   - 🚧 External reference import

### Current Tasks
1. Fix SwiftData concurrency issues in list views
2. Implement document editing interface
3. Add PDF viewer integration
4. Develop reference management system
5. Create note editing interface

Legend:
- ✅ Implemented
- 🚧 In Progress/Planned
- ❌ Blocked/Issues

## Technical Details
- Minimum iOS Version: iOS 17.0
- Minimum macOS Version: macOS 14.0
- Framework: SwiftUI
- Database: SwiftData
- Dependencies: None (core functionality)