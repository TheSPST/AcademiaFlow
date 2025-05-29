
//
//  OfflineSummarizationService.swift
//  AcademiaFlow
//
//  Created by Alex on 14/04/25.
//

import NaturalLanguage
import Foundation

actor OfflineSummarizationService {

    /// Generates an extractive summary from the given text.
    /// - Parameters:
    ///   - text: The input string to summarize.
    ///   - sentenceCount: The desired number of sentences in the summary.
    /// - Returns: A string containing the summary, or an empty string if summarization fails or text is empty.
    func summarize(text: String, sentenceCount: Int = 5) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return "" }

        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = trimmedText
        
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: trimmedText.startIndex..<trimmedText.endIndex) { tokenRange, _ in
            sentences.append(String(trimmedText[tokenRange]))
            return true
        }

        guard !sentences.isEmpty else {
            // If text doesn't break into sentences (e.g., a list of words, very short text),
            // return the original text if it's short enough, or a truncated version.
            return trimmedText.count <= 200 ? trimmedText : String(trimmedText.prefix(200)) + "..."
        }

        // A more advanced implementation would score sentences based on significance.
        // For now, we take the first `sentenceCount` sentences.
        // Consider also adding the last few sentences if the document is long,
        // or implementing a more sophisticated scoring mechanism (e.g., TF-IDF, keyword density).
        
        let summarySentences = Array(sentences.prefix(sentenceCount))
        
        return summarySentences.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
