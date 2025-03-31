import XCTest

final class ExportUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing", "enable-testing"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Helper Methods
    private func navigateToDocument() throws {
        // Wait for app to be ready
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        // Navigate to Documents
        let documentsButton = app.buttons["Documents"]
        XCTAssertTrue(documentsButton.waitForExistence(timeout: 5), "Documents button not found")
        documentsButton.tap()
        
        // Look for document in NavigationLink/List
        // First try direct navigation link
        let docNavigationLink = app.navigationBars["Documents"].firstMatch
        XCTAssertTrue(docNavigationLink.waitForExistence(timeout: 5), "Documents navigation bar not found")
        
        // Print all available elements for debugging
        print("\nAvailable elements in document list:")
        app.staticTexts.allElementsBoundByIndex.forEach { text in
            print("Text element: \(text.label)")
        }
        
        // Try to find and tap the document cell
        let docCell = app.cells.containing(.staticText, identifier: "UIKit vs SwiftUI").firstMatch
        guard docCell.waitForExistence(timeout: 5) else {
            // If cell not found, try finding just the title text
            let docText = app.staticTexts["UIKit vs SwiftUI"].firstMatch
            XCTAssertTrue(docText.exists, "Neither cell nor text for 'UIKit vs SwiftUI' found")
            docText.tap()
            return
        }
        
        // Tap the cell if found
        docCell.tap()
        
        // Verify we're in the document detail view
        let detailNavBar = app.navigationBars["UIKit vs SwiftUI"]
        XCTAssertTrue(detailNavBar.waitForExistence(timeout: 5), "Document detail view not loaded")
    }
    
    private func openExportSheet() throws {
        // Find and tap the export button
        let exportButton = app.buttons["square.and.arrow.up"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5), "Export button not found")
        exportButton.tap()
        
        // Verify export sheet appears
        let exportSheet = app.sheets["Export Document"]
        XCTAssertTrue(exportSheet.waitForExistence(timeout: 2), "Export sheet did not appear")
    }
    
    // MARK: - Debug Test
    func testUIElementsDiscovery() throws {
        // Wait for app to be ready
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        // Find and tap the Documents navigation
        let documentsNav = app.navigationBars.buttons["Documents"]
        if documentsNav.exists {
            documentsNav.tap()
        } else {
            let sidebarDocuments = app.buttons["Documents"]
            XCTAssertTrue(sidebarDocuments.waitForExistence(timeout: 5), "Documents button not found")
            sidebarDocuments.tap()
        }
        
        // Print the entire hierarchy
        print("\n=== UI HIERARCHY ===")
        print(app.debugDescription)
        
        // Print specific element types
        print("\n=== NAVIGATION BARS ===")
        app.navigationBars.allElementsBoundByIndex.forEach { nav in
            print(nav.debugDescription)
        }
        
        print("\n=== TABLES ===")
        app.tables.allElementsBoundByIndex.forEach { table in
            print(table.debugDescription)
        }
        
        print("\n=== CELLS ===")
        app.cells.allElementsBoundByIndex.forEach { cell in
            print(cell.debugDescription)
        }
        
        print("\n=== STATIC TEXT ===")
        app.staticTexts.allElementsBoundByIndex.forEach { text in
            print(text.debugDescription)
        }
        
        // Wait a moment to ensure list is loaded
        Thread.sleep(forTimeInterval: 1)
        
        // Try different ways to find cells
        let list = app.collectionViews.firstMatch
        if list.exists {
            print("\n=== LIST FOUND ===")
            print(list.debugDescription)
            list.cells.allElementsBoundByIndex.forEach { cell in
                print("List cell: \(cell.debugDescription)")
            }
        }
        
        let table = app.tables.firstMatch
        if table.exists {
            print("\n=== TABLE FOUND ===")
            print(table.debugDescription)
            table.cells.allElementsBoundByIndex.forEach { cell in
                print("Table cell: \(cell.debugDescription)")
            }
        }
        
        // Try to find any links
        print("\n=== LINKS ===")
        app.links.allElementsBoundByIndex.forEach { link in
            print(link.debugDescription)
        }
    }
    
    func testBasicDocumentNavigation() throws {
        // Wait for app to be ready
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        // Navigate to Documents
        let documentsButton = app.buttons["Documents"]
        XCTAssertTrue(documentsButton.waitForExistence(timeout: 5), "Documents button not found")
        documentsButton.tap()
        
        // Wait for a moment to let the list load
        Thread.sleep(forTimeInterval: 1)
        
        // Print the current UI state
        print("\nCurrent UI State after navigation:")
        print(app.debugDescription)
        
        // Try to find the list
        let list = app.collectionViews.firstMatch
        if list.exists {
            let cells = list.cells
            XCTAssertTrue(cells.count > 0, "No cells found in list")
            if let firstCell = cells.firstMatch as? XCUIElement {
                firstCell.tap()
            }
        }
    }
    
    // MARK: - Export UI Tests
    func testExportFlow() throws {
        // Navigate to document
        try navigateToDocument()
        
        // Open export sheet
        try openExportSheet()
        
        // Verify export options
        let exportSheet = app.sheets["Export Document"]
        
        // Check each export format option
        for format in ["PDF Document", "Markdown", "Plain Text"] {
            let formatButton = exportSheet.buttons[format]
            XCTAssertTrue(formatButton.exists, "\(format) button not found")
            XCTAssertTrue(formatButton.isEnabled, "\(format) button not enabled")
        }
        
        // Test export with PDF
        let pdfButton = exportSheet.buttons["PDF Document"]
        XCTAssertTrue(pdfButton.isHittable, "PDF button not hittable")
        pdfButton.tap()
        
        // Verify sheet dismissal
        XCTAssertFalse(exportSheet.exists, "Export sheet did not dismiss after selection")
    }
    
    func testCancelExport() throws {
        try navigateToDocument()
        try openExportSheet()
        
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists && cancelButton.isHittable, "Cancel button not available")
        cancelButton.tap()
        
        XCTAssertFalse(app.sheets["Export Document"].exists, "Export sheet did not dismiss")
    }
    
    // MARK: - Debug Helper
    func testDocumentListContent() throws {
        // Navigate to Documents
        let documentsButton = app.buttons["Documents"]
        XCTAssertTrue(documentsButton.waitForExistence(timeout: 5), "Documents button not found")
        documentsButton.tap()
        
        print("\n=== Document List Content ===")
        print("\nText Elements:")
        app.staticTexts.allElementsBoundByIndex.forEach { text in
            print("Text: \(text.label)")
        }
        
        print("\nCells:")
        app.cells.allElementsBoundByIndex.forEach { cell in
            print("Cell: \(cell.debugDescription)")
        }
        
        print("\nButtons:")
        app.buttons.allElementsBoundByIndex.forEach { button in
            print("Button: \(button.debugDescription)")
        }
        
        print("\nNavigation Links:")
        app.links.allElementsBoundByIndex.forEach { link in
            print("Link: \(link.debugDescription)")
        }
    }
}
