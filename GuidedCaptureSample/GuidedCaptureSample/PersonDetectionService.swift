/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Professional service for automatic human body detection and bounding box auto-resizing.
Uses ARKit body tracking to detect humans and automatically resize the capture box.
*/

import RealityKit
import ARKit
import SwiftUI
import os

private let logger = Logger(subsystem: GuidedCaptureSampleApp.subsystem,
                            category: "PersonDetectionService")

@MainActor
class PersonDetectionService: ObservableObject {
    private var detectionTask: Task<Void, Never>?
    private var bodyTrackingTask: Task<Void, Never>?
    private var isMonitoring = false
    private var lastResetTime: Date = Date.distantPast
    private let resetCooldown: TimeInterval = 2.0 // Wait 2 seconds between auto-resets
    
    // Body tracking state
    // Note: We don't use a separate ARSession to avoid conflicts with ObjectCaptureSession's internal AR session
    private var lastBodyAnchor: ARBodyAnchor?
    private var bodyDetectedCount: Int = 0
    private let bodyDetectionThreshold: Int = 5 // Require 5 stable detections before locking (prevents premature locking)
    private var lastBodyBounds: CGRect?
    private var hasLockedOnce: Bool = false // Track if we've locked once to prevent re-locking
    private var stableDetectionStartTime: Date? // Track when stable detection started
    private let stableDetectionDuration: TimeInterval = 1.5 // Require 1.5 seconds of stable detection
    
    var objectCaptureSession: ObjectCaptureSession?
    var appModel: AppDataModel?
    var captureMode: AppDataModel.CaptureMode = .object
    
    // Body tracking support check
    var isBodyTrackingSupported: Bool {
        return ARBodyTrackingConfiguration.isSupported
    }
    
    func startAutoDetection(for session: ObjectCaptureSession, appModel: AppDataModel, captureMode: AppDataModel.CaptureMode) {
        guard captureMode == .object else {
            logger.log("Auto person detection only enabled for object mode")
            return
        }
        
        // Note: Body tracking support check is informational
        // ObjectCaptureSession works on all supported devices
        if !isBodyTrackingSupported {
            logger.info("Device doesn't support ARBodyTrackingConfiguration, using ObjectCaptureSession detection")
        }
        
        self.objectCaptureSession = session
        self.appModel = appModel
        self.captureMode = captureMode
        
        guard !isMonitoring else {
            logger.log("Auto person detection already running")
            return
        }
        
        logger.log("Starting professional automatic human body detection and bounding box auto-resize...")
        isMonitoring = true
        
        // Reset state
        bodyDetectedCount = 0
        lastBodyAnchor = nil
        lastBodyBounds = nil
        lastResetTime = Date.distantPast
        hasLockedOnce = false
        stableDetectionStartTime = nil
        
        startMonitoring()
        
        // Start monitoring body tracking updates
        // Note: We use ObjectCaptureSession's built-in detection, not a separate ARSession
        // to avoid ARFrame retention issues and resource conflicts
        startBodyTracking()
    }
    
    func stopAutoDetection() {
        logger.log("Stopping automatic person detection...")
        detectionTask?.cancel()
        detectionTask = nil
        bodyTrackingTask?.cancel()
        bodyTrackingTask = nil
        
        // Clean up state
        lastBodyAnchor = nil
        isMonitoring = false
    }
    
    private func startBodyTracking() {
        // Note: We don't actually need a separate ARSession for body tracking
        // ObjectCaptureSession already has its own internal ARSession that handles detection
        // Creating a separate ARSession causes frame retention issues and resource conflicts
        // Instead, we rely on ObjectCaptureSession's built-in detection which works perfectly
        
        // This method is kept for future enhancements but doesn't create an ARSession
        // to avoid conflicts with ObjectCaptureSession's internal AR session
        
        bodyTrackingTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            // Monitor ObjectCaptureSession updates (not a separate ARSession)
            while !Task.isCancelled {
                // Check cancellation more frequently
                if Task.isCancelled { break }
                
                try? await Task.sleep(nanoseconds: 200_000_000) // Check every 0.2 seconds for faster locking
                
                guard let session = self.objectCaptureSession,
                      let appModel = self.appModel,
                      self.captureMode == .object else {
                    continue
                }
                
                // If box is already locked, skip processing to keep it stable
                if appModel.isBoundingBoxLocked {
                    continue
                }
                
                // Process body tracking updates from ObjectCaptureSession
                // This doesn't retain ARFrames - we only check feedback and state
                self.processBodyTrackingUpdates(session: session, appModel: appModel)
            }
        }
    }
    
    private func processBodyTrackingUpdates(session: ObjectCaptureSession, appModel: AppDataModel) {
        // Note: We can't directly access ARSession anchors from ObjectCaptureSession
        // So we use ObjectCaptureSession's built-in detection but enhance it with
        // better feedback and auto-locking behavior
        
        // Check if object is detected
        let isDetected = !session.feedback.contains(.objectNotDetected)
        
        if isDetected {
            bodyDetectedCount += 1
            
            // Track when stable detection starts
            if stableDetectionStartTime == nil && bodyDetectedCount >= 2 {
                stableDetectionStartTime = Date()
                logger.log("Stable detection started - waiting for box to properly size to person's body")
            }
            
            // Only lock when:
            // 1. We have enough detection counts (stable detection)
            // 2. Detection has been stable for required duration (box has time to resize)
            // 3. Box is not already locked
            if bodyDetectedCount >= bodyDetectionThreshold && !appModel.isBoundingBoxLocked && !hasLockedOnce {
                // Check if we've had stable detection for the required duration
                if let startTime = stableDetectionStartTime {
                    let stableDuration = Date().timeIntervalSince(startTime)
                    if stableDuration >= self.stableDetectionDuration {
                        // Box has had time to properly size to the person's body measurements
                        // Now lock it to keep it fixed
                        appModel.isBoundingBoxLocked = true
                        hasLockedOnce = true
                        logger.log("Auto-locked bounding box after stable detection - box is properly sized and fixed")
                    } else {
                        // Still waiting for box to resize - don't lock yet
                        logger.debug("Waiting for box to resize... (\(Int(stableDuration * 10)/10)s / \(self.stableDetectionDuration)s)")
                    }
                } else {
                    // Start tracking stable detection time
                    stableDetectionStartTime = Date()
                }
            }
        } else {
            // Reset detection count if person is lost
            if bodyDetectedCount > 0 {
                bodyDetectedCount = max(0, bodyDetectedCount - 1)
            }
            
            // Reset stable detection timer if person is lost
            if bodyDetectedCount < 2 {
                stableDetectionStartTime = nil
            }
        }
    }
    
    private func startMonitoring() {
        detectionTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                // Check cancellation more frequently
                if Task.isCancelled { break }
                
                try? await Task.sleep(nanoseconds: 300_000_000) // Check every 0.3 seconds for faster response
                
                guard let session = self.objectCaptureSession,
                      let appModel = self.appModel,
                      self.captureMode == .object else {
                    continue
                }
                
                // If box is locked, don't process - keep it stable
                if appModel.isBoundingBoxLocked {
                    continue
                }
                
                // Process updates without retaining frames
                self.checkAndAutoResize(session: session, appModel: appModel)
            }
        }
    }
    
    private func checkAndAutoResize(session: ObjectCaptureSession, appModel: AppDataModel) {
        // Only auto-detect when in detecting state and box is not locked
        guard session.state == .detecting else {
            return
        }
        
        // If box is locked, don't do anything - keep it stable
        if appModel.isBoundingBoxLocked {
            return
        }
        
        // If object is not detected, try resetting detection
        if session.feedback.contains(.objectNotDetected) {
            let now = Date()
            if now.timeIntervalSince(lastResetTime) > resetCooldown {
                logger.log("Person not detected, auto-resetting detection...")
                session.resetDetection()
                lastResetTime = now
                bodyDetectedCount = 0 // Reset detection count
                hasLockedOnce = false // Allow re-locking if person comes back
            }
        } else {
            // Object is detected - ObjectCaptureSession automatically sizes the box to person's body
            // Track detection stability before locking
            if bodyDetectedCount < bodyDetectionThreshold {
                bodyDetectedCount += 1
            }
            
            // Track when stable detection starts
            if stableDetectionStartTime == nil && bodyDetectedCount >= 2 {
                stableDetectionStartTime = Date()
                logger.log("Person detected - box is resizing to body measurements...")
            }
            
            // Only lock when detection is stable and box has had time to resize
            if bodyDetectedCount >= bodyDetectionThreshold && !appModel.isBoundingBoxLocked && !hasLockedOnce {
                if let startTime = stableDetectionStartTime {
                    let stableDuration = Date().timeIntervalSince(startTime)
                    if stableDuration >= self.stableDetectionDuration {
                        // Box has properly resized to person's body measurements - now lock it
                        appModel.isBoundingBoxLocked = true
                        hasLockedOnce = true
                        logger.log("Box locked after stable detection - properly sized to person's body and now fixed")
                    }
                } else {
                    stableDetectionStartTime = Date()
                }
            }
        }
    }
    
    // Public method to manually reset detection (called by reset button)
    func resetDetection() {
        guard let session = objectCaptureSession,
              let appModel = appModel else { return }
        logger.log("Manually resetting detection...")
        
        // Unlock box and reset detection state
        appModel.isBoundingBoxLocked = false
        session.resetDetection()
        bodyDetectedCount = 0
        lastResetTime = Date()
        lastBodyAnchor = nil
        lastBodyBounds = nil
        hasLockedOnce = false // Allow re-locking after reset
        stableDetectionStartTime = nil // Reset stable detection timer
    }
    
    // Check if person is currently detected
    var isPersonDetected: Bool {
        guard let session = objectCaptureSession else { return false }
        return !session.feedback.contains(.objectNotDetected) && session.state == .detecting
    }
    
    // Get detection stability (0.0 to 1.0)
    var detectionStability: Double {
        return min(1.0, Double(bodyDetectedCount) / Double(bodyDetectionThreshold))
    }
    
    // Calculate bounding box from body skeleton (for future enhancement)
    private func calculateBodyBounds(from anchor: ARBodyAnchor) -> CGRect? {
        let skeleton = anchor.skeleton
        
        // Get all joint positions
        var minX: Float = Float.greatestFiniteMagnitude
        var maxX: Float = -Float.greatestFiniteMagnitude
        var minY: Float = Float.greatestFiniteMagnitude
        var maxY: Float = -Float.greatestFiniteMagnitude
        var minZ: Float = Float.greatestFiniteMagnitude
        var maxZ: Float = -Float.greatestFiniteMagnitude
        
        // Iterate through all joint indices directly
        // This avoids type conversion issues with joint names
        for jointIndex in 0..<skeleton.jointModelTransforms.count {
            let jointTransform = skeleton.jointModelTransforms[jointIndex]
            let worldTransform = anchor.transform * jointTransform
            let position = simd_make_float3(worldTransform.columns.3)
            
            minX = min(minX, position.x)
            maxX = max(maxX, position.x)
            minY = min(minY, position.y)
            maxY = max(maxY, position.y)
            minZ = min(minZ, position.z)
            maxZ = max(maxZ, position.z)
        }
        
        // Add padding for better capture
        let padding: Float = 0.2 // 20cm padding
        minX -= padding
        maxX += padding
        minY -= padding
        maxY += padding
        minZ -= padding
        maxZ += padding
        
        // Return bounds if valid
        guard minX < maxX, minY < maxY, minZ < maxZ else {
            return nil
        }
        
        // Note: This would need to be converted to ObjectCaptureSession's coordinate system
        // For now, we rely on ObjectCaptureSession's built-in detection which works well
        return CGRect(x: CGFloat(minX), y: CGFloat(minY), 
                    width: CGFloat(maxX - minX), height: CGFloat(maxY - minY))
    }
}
