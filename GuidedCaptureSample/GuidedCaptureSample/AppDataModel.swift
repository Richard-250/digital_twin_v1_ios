/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A data model for maintaining the app state, including the underlying object capture state as well as any extra app state
 you maintain in addition, perhaps with invariants between them.
*/

import Foundation
import RealityKit
import SwiftUI
import os

private let logger = Logger(subsystem: GuidedCaptureSampleApp.subsystem,
                            category: "AppDataModel")

@MainActor
@Observable
class AppDataModel: Identifiable {
    static let instance = AppDataModel()

    /// When we start the capture phase, this will be set to the correct locations in the captureFolderManager.
    var objectCaptureSession: ObjectCaptureSession? {
        willSet {
            detachListeners()
        }
        didSet {
            guard objectCaptureSession != nil else { return }
            attachListeners()
        }
    }

    static let minNumImages = 10

    /// Once we are headed to reconstruction portion, we will hold the session here.
    private(set) var photogrammetrySession: PhotogrammetrySession?

    /// When we start a new capture, the folder will be set here.
    private(set) var captureFolderManager: CaptureFolderManager?

    /// Shows whether the user decided to skip reconstruction.
    private(set) var isSaveDraftEnabled = false

    var messageList = TimedMessageList()

    enum ModelState {
        case notSet
        case ready
        case capturing
        case prepareToReconstruct
        case reconstructing
        case viewing
        case completed
        case restart
        case failed
    }

    var state: ModelState = .notSet {
        didSet {
            logger.debug("didSet AppDataModel.state to \(String(describing: self.state))")
            performStateTransition(from: oldValue, to: state)
        }
    }

    var orbit: Orbit = .orbit1
    var isObjectFlipped: Bool = false

    var hasIndicatedObjectCannotBeFlipped: Bool = false
    var hasIndicatedFlipObjectAnyway: Bool = false
    var isObjectFlippable: Bool {
        // Override the objectNotFlippable feedback if the user has indicated
        // the object cannot be flipped or if they want to flip the object anyway
        guard !hasIndicatedObjectCannotBeFlipped else { return false }
        guard !hasIndicatedFlipObjectAnyway else { return true }
        guard let session = objectCaptureSession else { return true }
        return !session.feedback.contains(.objectNotFlippable)
    }

    enum CaptureMode: Equatable {
        case object
        case area
    }

    var captureMode: CaptureMode = .object
    
    // Track if bounding box should be locked (not auto-updated)
    var isBoundingBoxLocked: Bool = false
    
    // Person detection service for automatic bounding box resizing
    var personDetectionService = PersonDetectionService()

    // When state moves to failed, this is the error causing it.
    private(set) var error: Swift.Error?

    // Use setShowOverlaySheets(to:) to change this so you can maintain ObjectCaptureSession's pause state
    // properly because you don't hide the ObjectCaptureView. If you hide the ObjectCaptureView it pauses automatically.
    private(set) var showOverlaySheets = false

    // Shows whether the tutorial has played once during a session.
    var tutorialPlayedOnce = false

    // Postpone creating ObjectCaptureSession and PhotogrammetrySession until necessary.
    private init() {
        state = .ready
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAppTermination(notification:)),
                                               name: UIApplication.willTerminateNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        // Cancel tasks directly in deinit - handle main actor isolation
        if Thread.isMainThread {
            // We're on main thread, can safely access main actor isolated properties
            MainActor.assumeIsolated {
                for task in tasks {
                    task.cancel()
                }
                tasks.removeAll()
            }
        } else {
            // Not on main thread - dispatch to main thread synchronously
            DispatchQueue.main.sync {
                for task in tasks {
                    task.cancel()
                }
                tasks.removeAll()
            }
        }
    }

    /// Once reconstruction and viewing are complete, this should be called to let the app know it can go back to the new capture
    /// view.  We explicitly DO NOT destroy the model here to avoid transition state errors.  The splash screen will set up the
    /// AppDataModel to a clean slate when it starts.
    /// This can also be called after a cancelled or error reconstruction to go back to the start screen.
    func endCapture() {
        state = .completed
    }

    func removeCaptureFolder() {
        logger.log("Removing the capture folder...")
        guard let url = captureFolderManager?.captureFolder else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // Don't touch the showOverlaySheets directly, call setShowOverlaySheets() instead.
    // Since we use sheets and leave the ObjectCaptureView on screen and blur it underneath,
    // the session doesn't pause. We need to pause/resume the session by hand.
    func setShowOverlaySheets(to shown: Bool) {
        guard shown != showOverlaySheets else { return }
        if shown {
            showOverlaySheets = true
            objectCaptureSession?.pause()
        } else {
            objectCaptureSession?.resume()
            showOverlaySheets = false
        }
    }

    func saveDraft() {
        objectCaptureSession?.finish()
        isSaveDraftEnabled = true
    }

    // - MARK: Private Interface

    private var currentFeedback: Set<Feedback> = []

    private typealias Feedback = ObjectCaptureSession.Feedback
    private typealias Tracking = ObjectCaptureSession.Tracking

    private var tasks: [ Task<Void, Never> ] = []
}

extension AppDataModel {
    private func attachListeners() {
        logger.debug("Attaching listeners...")
        guard let model = objectCaptureSession else {
            fatalError("Logic error")
        }

        tasks.append(
            Task<Void, Never> { [weak self] in
                for await newFeedback in model.feedbackUpdates {
                    logger.debug("Task got async feedback change to: \(String(describing: newFeedback))")
                    self?.updateFeedbackMessages(for: newFeedback)
                }
                logger.log("^^^ Got nil from stateUpdates iterator!  Ending observation task...")
            })

        tasks.append(Task<Void, Never> { [weak self] in
            for await newState in model.stateUpdates {
                logger.debug("Task got async state change to: \(String(describing: newState))")
                self?.onStateChanged(newState: newState)
            }
            logger.log("^^^ Got nil from stateUpdates iterator!  Ending observation task...")
        })
    }

    private func detachListeners() {
        logger.debug("Detaching listeners...")
        for task in tasks {
            task.cancel()
        }
        tasks.removeAll()
    }

    @objc
    private func handleAppTermination(notification: Notification) {
        logger.log("Notification for the app termination is received...")
        if state == .ready || state == .capturing {
            removeCaptureFolder()
        }
    }

    // Should be called when a new capture is to be created, before the session will be needed.
    private func startNewCapture() throws {
        logger.log("startNewCapture() called...")
        if !ObjectCaptureSession.isSupported {
            preconditionFailure("ObjectCaptureSession is not supported on this device!")
        }

        captureFolderManager = try CaptureFolderManager()
        objectCaptureSession = ObjectCaptureSession()

        guard let session = objectCaptureSession else {
            preconditionFailure("startNewCapture() got unexpectedly nil session!")
        }

        guard let captureFolderManager else {
            preconditionFailure("captureFolderManager unexpectedly nil!")
        }

        var configuration = ObjectCaptureSession.Configuration()
        configuration.isOverCaptureEnabled = true
        configuration.checkpointDirectory = captureFolderManager.checkpointFolder
        
        // For body scanning, we want a larger initial detection area
        // The system will detect based on the person's size, but we guide users
        // to position themselves properly for optimal results
        
        // Starts the initial segment and sets the output locations.
        session.start(imagesDirectory: captureFolderManager.imagesFolder,
                      configuration: configuration)
        
        // Reset bounding box lock state for new capture
        isBoundingBoxLocked = false
        
        // Start automatic person detection for object mode
        if captureMode == .object {
            personDetectionService.startAutoDetection(for: session, appModel: self, captureMode: captureMode)
        }

        if case let .failed(error) = session.state {
            logger.error("Got error starting session! \(String(describing: error))")
            switchToErrorState(error: error)
        } else {
            state = .capturing
        }
    }

    private func switchToErrorState(error inError: Swift.Error) {
        // Set the error first since the transitions will assume it is non-nil!
        error = inError
        state = .failed
    }

    // Moves from prepareToReconstruct to .reconstructing.
    // Should be called from the ReconstructionPrimaryView async task once it is on the screen.
    private func startReconstruction() throws {
        logger.debug("startReconstruction() called.")

        var configuration = PhotogrammetrySession.Configuration()
        if captureMode == .area {
            configuration.isObjectMaskingEnabled = false
        }

        guard let captureFolderManager else {
            preconditionFailure("captureFolderManager unexpectedly nil!")
        }

        configuration.checkpointDirectory = captureFolderManager.checkpointFolder
        photogrammetrySession = try PhotogrammetrySession(
            input: captureFolderManager.imagesFolder,
            configuration: configuration)

        state = .reconstructing
    }

    private func reset() {
        logger.info("reset() called...")
        photogrammetrySession = nil
        objectCaptureSession = nil
        captureFolderManager = nil
        showOverlaySheets = false
        orbit = .orbit1
        isObjectFlipped = false
        currentFeedback = []
        messageList.removeAll()
        captureMode = .object
        isBoundingBoxLocked = false
        personDetectionService.stopAutoDetection()
        state = .ready
        isSaveDraftEnabled = false
        tutorialPlayedOnce = false
    }

    private func onStateChanged(newState: ObjectCaptureSession.CaptureState) {
        logger.info("OCViewModel switched to state: \(String(describing: newState))")
        if case .completed = newState {
            logger.log("ObjectCaptureSession moved in .completed state.")
            if isSaveDraftEnabled {
                logger.log("The data is stored. Closing the session...")
                reset()
            } else {
                logger.log("Switch app model to reconstruction...")
                state = .prepareToReconstruct
            }
        } else if case let .failed(error) = newState {
            logger.error("OCS moved to error state \(String(describing: error))...")
            if case ObjectCaptureSession.Error.cancelled = error {
                state = .restart
            } else {
                switchToErrorState(error: error)
            }
        }
    }

    private func updateFeedbackMessages(for feedback: Set<Feedback>) {
        // Compare the incoming feedback with the previous feedback to find the intersection.
        let persistentFeedback = currentFeedback.intersection(feedback)

        // Find the feedbacks that are not active anymore.
        let feedbackToRemove = currentFeedback.subtracting(persistentFeedback)
        for thisFeedback in feedbackToRemove {
            if let feedbackString = FeedbackMessages.getFeedbackString(for: thisFeedback, captureMode: captureMode) {
                messageList.remove(feedbackString)
            }
        }

        // Find the new feedbacks.
        let feebackToAdd = feedback.subtracting(persistentFeedback)
        for thisFeedback in feebackToAdd {
            if let feedbackString = FeedbackMessages.getFeedbackString(for: thisFeedback, captureMode: captureMode) {
                messageList.add(feedbackString)
            }
        }

        currentFeedback = feedback
    }

    private func performStateTransition(from fromState: ModelState, to toState: ModelState) {
        if fromState == toState { return }
        if fromState == .failed { error = nil }

        switch toState {
            case .ready:
                do {
                    try startNewCapture()
                } catch {
                    logger.error("Starting new capture failed!")
                }
            case .prepareToReconstruct:
                // Clean up the session to free GPU and memory resources.
                objectCaptureSession = nil
                do {
                    try startReconstruction()
                } catch {
                    logger.error("Reconstructing failed!")
                    switchToErrorState(error: error)
                }
            case .restart, .completed:
                reset()
            case .viewing:
                photogrammetrySession = nil
                
                // Save scan to history
                saveScanToHistory()
                
                removeCheckpointFolder()
            case .failed:
                logger.error("App failed state error=\(String(describing: self.error!))")
                // We will show error screen here
            default:
                break
        }
    }

    private func saveScanToHistory() {
        guard let captureFolderManager = captureFolderManager else { return }
        
        let modelURL = captureFolderManager.modelsFolder.appendingPathComponent("model-mobile.usdz")
        
        // Check if model file exists
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            logger.warning("Model file not found at \(modelURL.path)")
            return
        }
        
        // Create scan metadata
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let scanName = "Scan \(dateFormatter.string(from: Date()))"
        
        // Explicitly specify the type for nil thumbnailURL
        let scan = ScanMetadata(
            modelURL: modelURL,
            thumbnailURL: nil as URL?, // Could generate thumbnail later
            name: scanName
        )
        
        // Add to history
        ScanHistoryManager.shared.addScan(scan)
        logger.log("Saved scan to history: \(scanName)")
    }
    
    private func removeCheckpointFolder() {
        // Remove checkpoint folder to free up space now that the model is generated.
        if let captureFolderManager {
            // Capture only the URL to avoid Sendable issues
            let checkpointURL = captureFolderManager.checkpointFolder
            DispatchQueue.global(qos: .background).async {
                try? FileManager.default.removeItem(at: checkpointURL)
            }
        }
    }

    func determineCurrentOnboardingState() -> OnboardingState? {
        guard let session = objectCaptureSession else { return nil }

        switch captureMode {
            case .object:
                let orbitCompleted = session.userCompletedScanPass
                var currentState = OnboardingState.tooFewImages
                if session.numberOfShotsTaken >= AppDataModel.minNumImages {
                    switch orbit {
                        case .orbit1:
                            currentState = orbitCompleted ? .firstSegmentComplete : .firstSegmentNeedsWork
                        case .orbit2:
                            currentState = orbitCompleted ? .secondSegmentComplete : .secondSegmentNeedsWork
                        case .orbit3:
                            currentState = orbitCompleted ? .thirdSegmentComplete : .thirdSegmentNeedsWork
                        }
                }
                return currentState
            case .area:
                return .captureInAreaMode
        }
    }
}

// MARK: - Scan History Types
// These types are defined here to ensure they're accessible until the separate files are added to the Xcode project

struct ScanMetadata: Identifiable, Codable {
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
    
    // Custom Codable implementation to handle URLs
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
        self.scans.insert(scan, at: 0) // Add to beginning (most recent first)
        saveHistory()
        logger.log("Added scan to history: \(scan.name)")
    }
    
    func deleteScan(_ scan: ScanMetadata) {
        self.scans.removeAll { $0.id == scan.id }
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
            self.scans = []
            return
        }
        
        do {
            let data = try Data(contentsOf: historyFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decodedScans = try decoder.decode([ScanMetadata].self, from: data)
            
            // Filter out scans where model files no longer exist
            self.scans = decodedScans.filter { FileManager.default.fileExists(atPath: $0.modelURL.path) }
            
            logger.log("Loaded \(self.scans.count) scans from history")
        } catch {
            logger.error("Failed to load scan history: \(error.localizedDescription)")
            self.scans = []
        }
    }
    
    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(self.scans)
            try data.write(to: historyFileURL)
            logger.log("Saved \(self.scans.count) scans to history")
        } catch {
            logger.error("Failed to save scan history: \(error.localizedDescription)")
        }
    }
}
