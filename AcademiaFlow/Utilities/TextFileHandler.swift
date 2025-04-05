//
//  TextFileHandler.swift
//  AcademiaFlow
//
//  Created by Shubham Tomar on 04/04/25.
//
import Foundation
protocol TextFileHandler {
    /// Saves text content to a file at the specified path.
    /// - Parameters:
    ///   - text: The text content to save.
    ///   - filePath: The file location where the text should be saved.
    /// - Throws: An error if saving fails.
    func saveText(_ text: String, to filePath: String) throws
    
    /// Loads text content from a file at the specified path.
    /// - Parameter filePath: The file location to read from.
    /// - Returns: The text content read from the file.
    /// - Throws: An error if reading fails.
    func loadText(from filePath: String) throws -> String
}
//protocol FileManagerWrapper {
//    func fileExists(atPath path: String) -> Bool
//    
//}
