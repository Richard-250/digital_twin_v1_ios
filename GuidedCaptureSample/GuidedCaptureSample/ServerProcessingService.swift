/*
Server processing service to offload photogrammetry processing to local Mac server.
This Mac acts as the processing server - iPhone connects over local WiFi network.
*/

import Foundation
import os

private let logger = Logger(subsystem: GuidedCaptureSampleApp.subsystem, category: "ServerProcessingService")

@MainActor
class ServerProcessingService {
    static let shared = ServerProcessingService()
    
    // Server configuration
    // Use your Mac's hostname with .local - this NEVER changes!
    // The server shows the correct hostname when it starts (e.g., "MacBooks-MacBook-Air.local")
    // 
    // Current hostname from server: MacBooks-MacBook-Air.local
    // If this doesn't work, use the IP address shown when server starts
    private let serverBaseURL = "http://MacBooks-MacBook-Air.local:1100"  // Hostname (stable - never changes!)
    
    // VPN Note:
    // - Using THIS Mac as server on local WiFi: NO VPN needed (even if Mac has VPN)
    // - Using REMOTE server that requires VPN: BOTH iPhone AND server need VPN
    // - Current setup: Local Mac server - NO VPN required
    
    private init() {}
    
    // MARK: - Server Connection Test
    
    /// Tests if the server is reachable before attempting upload
    func testConnection() async throws -> Bool {
        logger.log("Testing server connection...")
        guard let url = URL(string: "\(serverBaseURL)/status/test") else {
            throw ServerError.serverUnreachable("Invalid server URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 90.0  // 5 second timeout
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                // Accept any response (even 404) - just means server is reachable
                logger.log("Server is reachable (status: \(httpResponse.statusCode))")
                return true
            }
        } catch {
            logger.error("Server connection test failed: \(error.localizedDescription)")
            throw ServerError.serverUnreachable("Cannot connect to server at \(serverBaseURL). Make sure:\n1. Server is running on your Mac\n2. iPhone and Mac are on same WiFi\n3. Mac's IP is correct: \(serverBaseURL)")
        }
        
        return false
    }
    
    // MARK: - Upload Images
    
    /// Uploads all images from the images folder to the server
    func uploadImages(from imagesFolder: URL, captureMode: AppDataModel.CaptureMode) async throws -> String {
        logger.log("Starting image upload to server...")
        
        // Get all image files
        let fileManager = FileManager.default
        let imageFiles = try fileManager.contentsOfDirectory(
            at: imagesFolder,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension.uppercased() == "HEIC" }
        
        guard !imageFiles.isEmpty else {
            throw ServerError.noImagesFound
        }
        
        logger.log("Found \(imageFiles.count) images to upload")
        
        // Create multipart form data
        var request = URLRequest(url: URL(string: "\(serverBaseURL)/upload")!)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add capture mode
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"mode\"\r\n\r\n".data(using: .utf8)!)
        body.append((captureMode == .area ? "area" : "object").data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add images
        for (index, imageURL) in imageFiles.enumerated() {
            let imageData = try Data(contentsOf: imageURL)
            let filename = imageURL.lastPathComponent
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"images\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/heic\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
            
            logger.log("Uploaded image \(index + 1)/\(imageFiles.count): \(filename)")
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        // Upload with extended timeout for large batches (up to 500 images)
        // Can take up to 1 hour for very large uploads - user is okay with this
        request.timeoutInterval = 7200.0  // 2 hours timeout (120 minutes) to handle 500+ images
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw ServerError.uploadFailed
            }
            
            // Parse job ID from response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let jobId = json["jobId"] as? String {
                logger.log("Upload successful. Job ID: \(jobId)")
                return jobId
            }
            
            throw ServerError.invalidResponse
        } catch let error as URLError {
            if error.code == .timedOut {
                throw ServerError.serverUnreachable("Upload timed out. Server may be unreachable or processing is taking too long.")
            } else if error.code == .cannotConnectToHost {
                throw ServerError.serverUnreachable("Cannot connect to server. Make sure server is running and iPhone/Mac are on same WiFi network.")
            } else {
                throw ServerError.uploadFailed
            }
        } catch {
            // Re-throw non-URLError exceptions
            throw error
        }
    }
    
    // MARK: - Check Processing Status
    
    /// Checks the processing status on the server
    func checkStatus(jobId: String) async throws -> ProcessingStatus {
        let url = URL(string: "\(serverBaseURL)/status/\(jobId)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ServerError.statusCheckFailed
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ServerError.invalidResponse
        }
        
        let status = json["status"] as? String ?? "unknown"
        let progress = json["progress"] as? Double ?? 0.0
        let stage = json["stage"] as? String
        
        return ProcessingStatus(
            status: status,
            progress: Float(progress),
            stage: stage
        )
    }
    
    // MARK: - Download Result
    
    /// Downloads the processed model from the server
    func downloadModel(jobId: String, to destinationURL: URL) async throws {
        logger.log("Downloading model for job \(jobId)...")
        
        guard let url = URL(string: "\(serverBaseURL)/download/\(jobId)") else {
            throw ServerError.downloadFailed
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3600.0  // 1 hour timeout for large file downloads
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type")
                throw ServerError.downloadFailed
            }
            
            guard httpResponse.statusCode == 200 else {
                logger.error("Download failed with status code: \(httpResponse.statusCode)")
                if let errorData = String(data: data, encoding: .utf8) {
                    logger.error("Error response: \(errorData)")
                }
                throw ServerError.downloadFailed
            }
            
            // Ensure destination directory exists
            let destinationDir = destinationURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: destinationDir,
                withIntermediateDirectories: true
            )
            
            // Write file
            try data.write(to: destinationURL)
            logger.log("Model downloaded successfully to \(destinationURL.path) (\(data.count) bytes)")
        } catch let error as URLError {
            logger.error("Network error during download: \(error.localizedDescription)")
            throw ServerError.downloadFailed
        } catch {
            logger.error("Download error: \(error.localizedDescription)")
            throw ServerError.downloadFailed
        }
    }
    
    // MARK: - Types
    
    struct ProcessingStatus {
        let status: String // "processing", "completed", "failed"
        let progress: Float // 0.0 to 1.0
        let stage: String? // Processing stage description
    }
    
    enum ServerError: LocalizedError {
        case noImagesFound
        case uploadFailed
        case statusCheckFailed
        case downloadFailed
        case invalidResponse
        case serverUnreachable(String)
        
        var errorDescription: String? {
            switch self {
            case .noImagesFound:
                return "No images found to upload"
            case .uploadFailed:
                return "Failed to upload images to server"
            case .statusCheckFailed:
                return "Failed to check processing status"
            case .downloadFailed:
                return "Failed to download processed model"
            case .invalidResponse:
                return "Invalid response from server"
            case .serverUnreachable(let message):
                return message
            }
        }
    }
}

