import SwiftUI
import SwiftData

struct ReferenceDetailView: View {
    let reference: Reference
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(reference.title)
                .font(.title)
            
            if !reference.authors.isEmpty {
                Text("Authors: \(reference.authors.joined(separator: ", "))")
                    .font(.headline)
            }
            
            if let year = reference.year {
                Text("Year: \(year)")
            }
            
            if let doi = reference.doi {
                Text("DOI: \(doi)")
            }
            
            if let url = reference.url {
                Link("URL", destination: url)
            }
            
            if let abstract = reference.abstract {
                Text("Abstract:")
                    .font(.headline)
                Text(abstract)
                    .font(.body)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}