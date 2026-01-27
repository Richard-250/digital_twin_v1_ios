/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Manager for saving and retrieving scan history metadata.
*/

import Foundation
import os

private let logger = Logger(subsystem: GuidedCaptureSampleApp.subsystem,
                            category: "ScanHistoryManager")

struct ScanMetadata: Identifiable {
    let id: String
    let modelURL: URL
    let thumbnailURL: URL?
    let dateCreated: Date
    let name: String
    
    init(id: String = UUID().uuidString, modelURL: URL, thumbnailURL: URL? = nil, dateCreated: Date = Date(), name: String) {
        self.id = id
        self.modelURL = modelURL
        self.thumbnailURL = thumbnailURL
        self.dateCreated = dateCreated
        self.name = name
    }
}

@MainActor
@Observable
class ScanHistoryManager {
    static let shared = ScanHistoryManager()
    
    private let historyFileName = "scan_history.json"
    private var historyFileURL: URL {
        URL.documentsDirectory.appendingPathComponent(historyFileName)
    }
    
    var scans: [ScanMetadata] = []
    
    private init() {
        loadHistory()
    }
    
    func addScan(_ scan: ScanMetadata) {
        scans.insert(scan, at: 0) // Add to beginning (most recent first)
        saveHistory()
        logger.log("Added scan to history: \(scan.name)")
    }
    
    func deleteScan(_ scan: ScanMetadata) {
        scans.removeAll { $0.id == scan.id }
        saveHistory()
        
        // Delete the model file if it exists
        if FileManager.default.fileExists(atPath: scan.modelURL.path) {
            try? FileManager.default.removeItem(at: scan.modelURL)
        }
        
        // Delete thumbnail if it exists
        if let thumbnailURL = scan.thumbnailURL,
           FileManager.default.fileExists(atPath: thumbnailURL.path) {
            try? FileManager.default.removeItem(at: thumbnailURL)
        }
        
        logger.log("Deleted scan from history: \(scan.name)")
    }
    
    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
            scans = []
            return
        }
        
        do {
            let data = try Data(contentsOf: historyFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            scans = try decoder.decode([ScanMetadata].self, from: data)
            
            // Filter out scans where model files no longer exist
            scans = scans.filter { FileManager.default.fileExists(atPath: $0.modelURL.path) }
            
            logger.log("Loaded \(scans.count) scans from history")
        } catch {
            logger.error("Failed to load scan history: \(error.localizedDescription)")
            scans = []
        }
    }
    
    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(scans)
            try data.write(to: historyFileURL)
            logger.log("Saved \(scans.count) scans to history")
        } catch {
            logger.error("Failed to save scan history: \(error.localizedDescription)")
        }
    }
}

// Custom Codable implementation for ScanMetadata to handle URLs
extension ScanMetadata: Codable {
    enum CodingKeys: String, CodingKey {
        case id, dateCreated, name, modelURLPath, thumbnailURLPath
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        dateCreated = try container.decode(Date.self, forKey: .dateCreated)
        name = try container.decode(String.self, forKey: .name)
        
        let modelPath = try container.decode(String.self, forKey: .modelURLPath)
        modelURL = URL(fileURLWithPath: modelPath)
        
        thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURLPath).map { URL(fileURLWithPath: $0) }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(dateCreated, forKey: .dateCreated)
        try container.encode(name, forKey: .name)
        try container.encode(modelURL.path, forKey: .modelURLPath)
        try container.encodeIfPresent(thumbnailURL?.path, forKey: .thumbnailURLPath)
    }
}

