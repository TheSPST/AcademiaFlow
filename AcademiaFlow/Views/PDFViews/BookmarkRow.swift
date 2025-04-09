//
//  BookmarkRow.swift
//  AcademiaFlow
//
//  Created by Shubham Tomar on 09/04/25.
//
import SwiftUI

struct BookmarkRow: View {
    let bookmark: PDFBookmark
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Page \(bookmark.pageLabel)")
                    .font(.headline)
                Text(bookmark.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "bookmark.fill")
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
}
