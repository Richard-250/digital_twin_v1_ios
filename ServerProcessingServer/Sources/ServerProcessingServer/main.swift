/*
macOS Swift Server using PhotogrammetrySession API
This uses the same Swift code as iOS but runs on macOS server
*/

import Foundation
import RealityKit
import Vapor
import MultipartKit
import NIOCore
#if canImport(Darwin)
import Darwin
#endif

// Job tracking
class ProcessingJob {
    var status: String // "processing", "completed", "failed"
    var progress: Float
    var stage: String?
    var jobId: String
    var imagesFolder: URL
    var outputFile: URL?
    var session: PhotogrammetrySession?
    
    init(status: String, progress: Float, stage: String?, jobId: String, imagesFolder: URL, outputFile: URL?) {
        self.status = status
        self.progress = progress
        self.stage = stage
        self.jobId = jobId
        self.imagesFolder = imagesFolder
        self.outputFile = outputFile
    }
}

var jobs: [String: ProcessingJob] = [:]
let jobsLock = NSLock()

// Helper to safely update job status
func withJobLock<T>(_ block: () throws -> T) rethrows -> T {
    jobsLock.lock()
    defer { jobsLock.unlock() }
    return try block()
}

func configure(_ app: Application) throws {
    // Configure server host and port
    app.http.server.configuration.hostname = "0.0.0.0"  // Listen on all interfaces
    app.http.server.configuration.port = 1100
    
    // Increase default max body size for very large image uploads (10GB)
    // Supports up to 500 HEIC images at high resolution (20MB average = 10GB total)
    app.routes.defaultMaxBodySize = "10gb"
    
    // Routes
    // Health check endpoint for connection testing
    app.get("status", "test") { req -> Response in
        // Return JSON with proper content type for browser display
        let response: [String: String] = ["status": "Server is running"]
        let responseData = try JSONEncoder().encode(response)
        var headers = HTTPHeaders()
        headers.contentType = .json
        return Response(status: .ok, headers: headers, body: .init(data: responseData))
    }
    
    // Upload endpoint with very large body size support (20GB to handle 500+ high-res images)
    // Can take up to 1 hour to upload - timeout handled by client
    app.on(.POST, "upload", body: .collect(maxSize: "20gb")) { req -> EventLoopFuture<Response> in
        return try handleUpload(req: req)
    }
    
    app.get("status", ":jobId") { req -> EventLoopFuture<Response> in
        let jobId = req.parameters.get("jobId")!
        return handleStatus(jobId: jobId, req: req)
    }
    
    app.get("download", ":jobId") { req -> EventLoopFuture<Response> in
        let jobId = req.parameters.get("jobId")!
        return handleDownload(jobId: jobId, req: req)
    }
}

// Helper class for multipart parsing
class MultipartParserHelper {
    var parts: [MultipartPart] = []
    var currentHeaders = HTTPHeaders()
    var currentBody = ByteBuffer()
    
    func setup(parser: MultipartParser) {
        parser.onHeader = { [weak self] name, value in
            self?.currentHeaders.replaceOrAdd(name: name, value: value)
        }
        
        parser.onBody = { [weak self] buffer in
            var bodyBuffer = buffer
            self?.currentBody.writeBuffer(&bodyBuffer)
        }
        
        parser.onPartComplete = { [weak self] in
            guard let self = self else { return }
            let part = MultipartPart(headers: self.currentHeaders, body: self.currentBody)
            self.parts.append(part)
            self.currentHeaders = HTTPHeaders()
            self.currentBody = ByteBuffer()
        }
    }
}

func handleUpload(req: Request) throws -> EventLoopFuture<Response> {
    let jobId = UUID().uuidString
    
    return req.body.collect().flatMapThrowing { body -> Response in
        print("[UPLOAD] Starting upload for job: \(jobId)")
        
        // Create job directory
        let uploadsDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("photogrammetry_uploads")
            .appendingPathComponent(jobId)
        
        try FileManager.default.createDirectory(
            at: uploadsDir,
            withIntermediateDirectories: true
        )
        print("[UPLOAD] Created upload directory: \(uploadsDir.path)")
        
        // Get boundary from content type
        guard let contentType = req.headers.contentType,
              let boundary = contentType.parameters["boundary"] else {
            print("[UPLOAD] ERROR: Missing boundary in Content-Type")
            throw Abort(.badRequest, reason: "Missing boundary in Content-Type")
        }
        print("[UPLOAD] Boundary: \(boundary)")
        
        // Parse multipart data using MultipartParser
        guard let bodyBuffer = body else {
            print("[UPLOAD] ERROR: Empty request body")
            throw Abort(.badRequest, reason: "Empty request body")
        }
        
        print("[UPLOAD] Body size: \(bodyBuffer.readableBytes) bytes")
        
        let parser = MultipartParser(boundary: boundary)
        let helper = MultipartParserHelper()
        helper.setup(parser: parser)
        
        do {
            try parser.execute(bodyBuffer)
            print("[UPLOAD] Parsed \(helper.parts.count) parts")
        } catch {
            print("[UPLOAD] ERROR parsing multipart: \(error)")
            throw Abort(.badRequest, reason: "Failed to parse multipart data: \(error.localizedDescription)")
        }
        
        var isAreaMode = false
        var imageCount = 0
        
        // Process parts
        for (index, part) in helper.parts.enumerated() {
            print("[UPLOAD] Processing part \(index + 1): name=\(part.name ?? "nil"), filename=\(part.filename ?? "nil")")
            
            // Check for mode field
            if let name = part.name, name == "mode" {
                if let modeString = part.body.getString(at: 0, length: part.body.readableBytes)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    isAreaMode = (modeString == "area")
                    print("[UPLOAD] Mode: \(modeString) (isAreaMode: \(isAreaMode))")
                }
            }
            
            // Check for image files (has filename or name is "images")
            if part.filename != nil || part.name == "images" {
                let imageFilename = part.filename ?? "image_\(imageCount).heic"
                let fileURL = uploadsDir.appendingPathComponent(imageFilename)
                guard let imageData = part.body.getData(at: 0, length: part.body.readableBytes) else {
                    print("[UPLOAD] WARNING: Could not get image data for part \(index + 1)")
                    continue
                }
                try imageData.write(to: fileURL)
                print("[UPLOAD] Saved image \(imageCount + 1): \(imageFilename) (\(imageData.count) bytes)")
                imageCount += 1
            }
        }
        
        guard imageCount > 0 else {
            print("[UPLOAD] ERROR: No images uploaded")
            throw Abort(.badRequest, reason: "No images uploaded")
        }
        
        print("[UPLOAD] Successfully received \(imageCount) images")
        
        // Create output file
        let resultsDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("photogrammetry_results")
        try FileManager.default.createDirectory(
            at: resultsDir,
            withIntermediateDirectories: true
        )
        let outputFile = resultsDir.appendingPathComponent("\(jobId).usdz")
        
        // Ensure output file doesn't exist (remove if it does)
        if FileManager.default.fileExists(atPath: outputFile.path) {
            try? FileManager.default.removeItem(at: outputFile)
        }
        
        print("[UPLOAD] Output file will be: \(outputFile.path)")
        
        // Initialize job
        let job = ProcessingJob(
            status: "processing",
            progress: 0.0,
            stage: "Initializing...",
            jobId: jobId,
            imagesFolder: uploadsDir,
            outputFile: outputFile
        )
        
        jobsLock.lock()
        jobs[jobId] = job
        jobsLock.unlock()
        
        print("[UPLOAD] Job created: \(jobId)")
        
        // Start processing in background (fire and forget)
        if #available(macOS 14.0, *) {
            Task.detached {
                await processImages(job: job, isAreaMode: isAreaMode)
            }
        } else {
            // macOS version too old - mark job as failed
            withJobLock {
                job.status = "failed"
                job.stage = "Error: macOS 14.0 or later required for PhotogrammetrySession"
            }
            print("[UPLOAD] ERROR: macOS version too old. Requires macOS 14.0+")
        }
        
        let response: [String: String] = [
            "jobId": jobId,
            "message": "Upload successful"
        ]
        
        let responseData = try JSONEncoder().encode(response)
        print("[UPLOAD] Upload completed successfully for job: \(jobId)")
        return Response(status: .ok, body: .init(data: responseData))
    }
}

@available(macOS 14.0, *)
func processImages(job: ProcessingJob, isAreaMode: Bool) async {
    do {
        // Update status
        withJobLock {
            job.stage = "Configuring session..."
            job.progress = 0.05
        }
        
        // Configure PhotogrammetrySession
        var configuration = PhotogrammetrySession.Configuration()
        if isAreaMode {
            configuration.isObjectMaskingEnabled = false
        }
        
        // Create checkpoint directory
        let checkpointDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("photogrammetry_checkpoints")
            .appendingPathComponent(job.jobId)
        try FileManager.default.createDirectory(
            at: checkpointDir,
            withIntermediateDirectories: true
        )
        configuration.checkpointDirectory = checkpointDir
        
        // Create session
        let session = try PhotogrammetrySession(
            input: job.imagesFolder,
            configuration: configuration
        )
        
        withJobLock {
            job.session = session
        }
        
        // Process - start the session processing
        print("[PROCESSING] Starting processing for job \(job.jobId)")
        print("[PROCESSING] Images folder: \(job.imagesFolder.path)")
        print("[PROCESSING] Output file: \(job.outputFile!.path)")
        
        // Verify images folder exists and has images
        guard FileManager.default.fileExists(atPath: job.imagesFolder.path) else {
            let errorMsg = "Images folder does not exist: \(job.imagesFolder.path)"
            print("[PROCESSING] ERROR: \(errorMsg)")
            withJobLock {
                job.status = "failed"
                job.stage = errorMsg
            }
            return
        }
        
        let imageFiles = try? FileManager.default.contentsOfDirectory(at: job.imagesFolder, includingPropertiesForKeys: nil)
        let imageCount = imageFiles?.count ?? 0
        print("[PROCESSING] Found \(imageCount) images in folder")
        
        guard imageCount > 0 else {
            let errorMsg = "No images found in folder: \(job.imagesFolder.path)"
            print("[PROCESSING] ERROR: \(errorMsg)")
            withJobLock {
                job.status = "failed"
                job.stage = errorMsg
            }
            return
        }
        
        // Ensure output directory exists
        let outputDir = job.outputFile!.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        print("[PROCESSING] Output directory verified: \(outputDir.path)")
        
        do {
            try session.process(requests: [.modelFile(url: job.outputFile!)])
            print("[PROCESSING] Session processing started successfully")
        } catch {
            let errorMsg = "Failed to start processing: \(error.localizedDescription)"
            print("[PROCESSING] ERROR: \(errorMsg)")
            print("[PROCESSING] Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                print("[PROCESSING] NSError domain: \(nsError.domain), code: \(nsError.code)")
                print("[PROCESSING] NSError userInfo: \(nsError.userInfo)")
            }
            withJobLock {
                job.status = "failed"
                job.stage = errorMsg
            }
            return
        }
        
        // Monitor progress from session outputs
        do {
            for try await output in session.outputs {
                print("[PROCESSING] Received output for job \(job.jobId): \(output)")
                
                withJobLock {
                    switch output {
                    case .requestProgress(_, let fractionComplete):
                        job.progress = Float(fractionComplete)
                        print("[PROCESSING] Progress: \(Int(fractionComplete * 100))%")
                        
                    case .requestProgressInfo(_, let progressInfo):
                        if let stage = progressInfo.processingStage {
                            let stageStr = stageString(stage)
                            job.stage = stageStr
                            print("[PROCESSING] Stage: \(stageStr)")
                        } else {
                            job.stage = "Processing..."
                        }
                        
                    case .processingComplete:
                        job.status = "completed"
                        job.progress = 1.0
                        job.stage = "Processing complete"
                        print("[PROCESSING] Processing completed successfully for job \(job.jobId)")
                        
                    case .requestError(_, let error):
                        let errorDescription = "Error: \(error.localizedDescription)"
                        print("[PROCESSING] Request error for job \(job.jobId): \(errorDescription)")
                        print("[PROCESSING] Error details: \(error)")
                        if let nsError = error as NSError? {
                            print("[PROCESSING] Error domain: \(nsError.domain), code: \(nsError.code)")
                            print("[PROCESSING] Error userInfo: \(nsError.userInfo)")
                        }
                        job.status = "failed"
                        job.stage = errorDescription
                        
                    default:
                        break
                    }
                }
                
                // Break if completed or failed
                let shouldBreak: Bool = withJobLock {
                    return job.status == "completed" || job.status == "failed"
                }
                
                if shouldBreak {
                    print("[PROCESSING] Breaking output loop - status: \(withJobLock { job.status })")
                    break
                }
            }
        } catch {
            let errorMsg = "Error reading session outputs: \(error.localizedDescription)"
            print("[PROCESSING] EXCEPTION: \(errorMsg)")
            print("[PROCESSING] Exception type: \(type(of: error))")
            if let nsError = error as NSError? {
                print("[PROCESSING] NSError domain: \(nsError.domain), code: \(nsError.code)")
                print("[PROCESSING] NSError userInfo: \(nsError.userInfo)")
            }
            withJobLock {
                job.status = "failed"
                job.stage = errorMsg
            }
            return
        }
        
        // Ensure final status is set
        withJobLock {
            if job.status == "processing" {
                job.status = "completed"
                job.progress = 1.0
                job.stage = "Processing complete"
            }
        }
        
    } catch {
        withJobLock {
            job.status = "failed"
            job.stage = "Error: \(error.localizedDescription)"
        }
    }
}

@available(macOS 14.0, *)
func stageString(_ stage: PhotogrammetrySession.Output.ProcessingStage) -> String {
    switch stage {
    case .preProcessing: return "Preprocessing..."
    case .imageAlignment: return "Aligning images..."
    case .pointCloudGeneration: return "Generating point cloud..."
    case .meshGeneration: return "Generating mesh..."
    case .textureMapping: return "Mapping texture..."
    case .optimization: return "Optimizing..."
    default: return "Processing..."
    }
}

func handleStatus(jobId: String, req: Request) -> EventLoopFuture<Response> {
    jobsLock.lock()
    guard let job = jobs[jobId] else {
        jobsLock.unlock()
        return req.eventLoop.makeFailedFuture(Abort(.notFound, reason: "Job not found"))
    }
    let status = job.status
    let progress = job.progress
    let stage = job.stage ?? "Processing..."
    jobsLock.unlock()
    
    let response: [String: Any] = [
        "status": status,
        "progress": progress,
        "stage": stage
    ]
    
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: response)
        return req.eventLoop.makeSucceededFuture(
            Response(status: .ok, body: .init(data: jsonData))
        )
    } catch {
        return req.eventLoop.makeFailedFuture(error)
    }
}

func handleDownload(jobId: String, req: Request) -> EventLoopFuture<Response> {
    // Get job info with lock
    let jobInfo: (ProcessingJob, String, URL)? = withJobLock {
        guard let job = jobs[jobId],
              job.status == "completed",
              let outputFile = job.outputFile else {
            return nil
        }
        return (job, outputFile.path, outputFile)
    }
    
    guard let (job, filePath, outputFile) = jobInfo else {
        return req.eventLoop.makeFailedFuture(Abort(.notFound, reason: "Job not completed or not found"))
    }
    
    guard FileManager.default.fileExists(atPath: filePath) else {
        return req.eventLoop.makeFailedFuture(Abort(.notFound, reason: "Output file not found at path: \(filePath)"))
    }
    
    do {
        // Read file data
        let data = try Data(contentsOf: outputFile)
        
        // Create response with proper headers for USDZ file download
        var headers = HTTPHeaders()
        headers.contentType = .init(type: "model", subType: "usd")
        headers.add(name: "Content-Disposition", value: "attachment; filename=\"\(jobId).usdz\"")
        headers.add(name: "Content-Length", value: "\(data.count)")
        
        print("[DOWNLOAD] Serving file for job \(jobId): \(filePath) (\(data.count) bytes)")
        
        return req.eventLoop.makeSucceededFuture(
            Response(status: .ok, headers: headers, body: .init(data: data))
        )
    } catch {
        print("[DOWNLOAD] ERROR: Failed to read file \(filePath): \(error.localizedDescription)")
        return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Failed to read file: \(error.localizedDescription)"))
    }
}

// Helper to get local IP address
func getLocalIP() -> String {
    var address = "127.0.0.1"
    var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
    guard getifaddrs(&ifaddr) == 0 else { return address }
    guard let firstAddr = ifaddr else { return address }
    
    for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
        let interface = ifptr.pointee
        let addrFamily = interface.ifa_addr.pointee.sa_family
        
        if addrFamily == UInt8(AF_INET) {
            let name = String(cString: interface.ifa_name)
            if name == "en0" || name.hasPrefix("en") { // WiFi or Ethernet
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                           &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                address = String(cString: hostname)
                if !address.hasPrefix("127.") && !address.hasPrefix("169.254.") {
                    break
                }
            }
        }
    }
    freeifaddrs(ifaddr)
    return address
}

// Helper to get hostname
func getHostname() -> String? {
    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
    guard gethostname(&hostname, hostname.count) == 0 else { return nil }
    let name = String(cString: hostname)
    return name.hasSuffix(".local") ? name : "\(name).local"
}

// Run server  
var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)

let app = Application(env)
defer { app.shutdown() }

// Print server info
let localIP = getLocalIP()
let hostname = getHostname() ?? "unknown"

print(String(repeating: "=", count: 60))
print("Starting Swift Photogrammetry Processing Server")
print(String(repeating: "=", count: 60))
print("Server is running on port 1100")
print("")
print("Access from iPhone using ONE of these:")
print("  • IP Address:    http://\(localIP):1100")
if hostname != "unknown" {
    print("  • Hostname:      http://\(hostname):1100  (RECOMMENDED - never changes!)")
}
print("")
print("IMPORTANT:")
print("  • iPhone and Mac must be on same WiFi network")
print("  • Use the hostname (.local) if possible - it never changes!")
print("  • If hostname doesn't work, use the IP address above")
print(String(repeating: "=", count: 60))

try configure(app)
try app.run()
