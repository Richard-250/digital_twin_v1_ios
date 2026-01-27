/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view to show during the reconstruction phase, with a progress update from the outputs `AsyncSequence`, until the model output is completed.
*/

import RealityKit
import SwiftUI
import os

private let logger = Logger(subsystem: GuidedCaptureSampleApp.subsystem, category: "ReconstructionPrimaryView")

struct ReconstructionPrimaryView: View {
    @Environment(AppDataModel.self) var appModel
    let outputFile: URL

    @State private var completed: Bool = false
    @State private var cancelled: Bool = false

    var body: some View {
        if completed && !cancelled {
            // Show the model - user can view interactive version from gallery
            ModelView(modelFile: outputFile, endCaptureCallback: {
                appModel.endCapture()
            })
            .onAppear(perform: {
                UIApplication.shared.isIdleTimerDisabled = false
            })
        } else {
            ReconstructionProgressView(outputFile: outputFile,
                                       completed: $completed,
                                       cancelled: $cancelled)
        }
    }
}

struct ReconstructionProgressView: View {
    @Environment(AppDataModel.self) var appModel
    let outputFile: URL
    @Binding var completed: Bool
    @Binding var cancelled: Bool

    @State private var progress: Float = 0
    @State private var estimatedRemainingTime: TimeInterval?
    @State private var processingStageDescription: String?
    @State private var pointCloud: PhotogrammetrySession.PointCloud?
    @State private var gotError: Bool = false
    @State private var error: Error?
    @State private var isCancelling: Bool = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var padding: CGFloat {
        horizontalSizeClass == .regular ? 60.0 : 24.0
    }
    private func isReconstructing() -> Bool {
        return !completed && !gotError && !cancelled
    }

    var body: some View {
        VStack(spacing: 0) {
            if isReconstructing() {
                HStack {
                    Button(action: {
                        logger.log("Canceling...")
                        isCancelling = true
                        cancelled = true
                        appModel.state = .restart
                    }, label: {
                        Text(LocalizedString.cancel)
                            .font(.headline)
                            .bold()
                            .padding(30)
                            .foregroundColor(.blue)
                    })
                    .padding(.trailing)

                    Spacer()
                }
            }

            Spacer()

            TitleView()

            Spacer()

            ProgressBarView(progress: progress,
                            estimatedRemainingTime: estimatedRemainingTime,
                            processingStageDescription: processingStageDescription)
            .padding(padding)

            Spacer()
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 20)
        .alert(
            "Failed:  " + (error != nil  ? "\(String(describing: error!))" : ""),
            isPresented: $gotError,
            actions: {
                Button("OK") {
                    logger.log("Calling restart...")
                    appModel.state = .restart
                }
            },
            message: {}
        )
        .task {
            precondition(appModel.state == .reconstructing)
            await processOnServer()
        }  // task
    }
    
    // MARK: - Server Processing
    
    private func processOnServer() async {
        guard let captureFolderManager = appModel.captureFolderManager else {
            logger.error("Capture folder manager unavailable")
            gotError = true
            error = ServerProcessingService.ServerError.invalidResponse
            return
        }
        
        let service = ServerProcessingService.shared
        
        do {
            // Step 0: Test server connection first
            logger.log("Testing server connection...")
            processingStageDescription = "Checking server connection..."
            progress = 0.05
            
            do {
                _ = try await service.testConnection()
                logger.log("Server connection successful")
            } catch {
                logger.error("Server connection failed: \(error.localizedDescription)")
                gotError = true
                self.error = error
                return
            }
            
            // Step 1: Upload images to server
            logger.log("Uploading images to server...")
            processingStageDescription = "Uploading images to server..."
            progress = 0.1
            
            let jobId = try await service.uploadImages(
                from: captureFolderManager.imagesFolder,
                captureMode: appModel.captureMode
            )
            
            logger.log("Upload complete. Job ID: \(jobId)")
            progress = 0.2
            processingStageDescription = "Processing on server..."
            
            // Step 2: Poll for status until complete
            var isProcessing = true
            while isProcessing && !cancelled && !gotError {
                try await Task.sleep(nanoseconds: 2_000_000_000) // Poll every 2 seconds
                
                let status = try await service.checkStatus(jobId: jobId)
                
                progress = 0.2 + (status.progress * 0.7) // 20% to 90%
                processingStageDescription = status.stage ?? "Processing on server..."
                
                switch status.status {
                case "completed":
                    isProcessing = false
                    logger.log("Processing completed on server")
                    
                    // Step 3: Download the result
                    processingStageDescription = "Downloading model..."
                    progress = 0.9
                    
                    try await service.downloadModel(jobId: jobId, to: outputFile)
                    
                    progress = 1.0
                    completed = true
                    appModel.state = .viewing
                    
                case "failed":
                    isProcessing = false
                    gotError = true
                    error = ServerProcessingService.ServerError.downloadFailed
                    logger.error("Processing failed on server")
                    
                default:
                    // Continue polling
                    break
                }
            }
            
            if cancelled {
                logger.log("Processing cancelled by user")
                appModel.state = .restart
            }
            
        } catch {
            logger.error("Server processing error: \(error.localizedDescription)")
            gotError = true
            self.error = error
        }
    }

    struct LocalizedString {
        static let cancel = NSLocalizedString(
            "Cancel (Object Reconstruction)",
            bundle: Bundle.main,
            value: "Cancel",
            comment: "Button title to cancel reconstruction.")
    }

}

extension PhotogrammetrySession.Output.ProcessingStage {
    var processingStageString: String? {
        switch self {
            case .preProcessing:
                return NSLocalizedString(
                    "Preprocessing (Reconstruction)",
                    bundle: Bundle.main,
                    value: "Preprocessing…",
                    comment: "Feedback message during the object reconstruction phase."
                )
            case .imageAlignment:
                return NSLocalizedString(
                    "Aligning Images (Reconstruction)",
                    bundle: Bundle.main,
                    value: "Aligning Images…",
                    comment: "Feedback message during the object reconstruction phase."
                )
            case .pointCloudGeneration:
                return NSLocalizedString(
                    "Generating Point Cloud (Reconstruction)",
                    bundle: Bundle.main,
                    value: "Generating Point Cloud…",
                    comment: "Feedback message during the object reconstruction phase."
                )
            case .meshGeneration:
                return NSLocalizedString(
                    "Generating Mesh (Reconstruction)",
                    bundle: Bundle.main,
                    value: "Generating Mesh…",
                    comment: "Feedback message during the object reconstruction phase."
                )
            case .textureMapping:
                return NSLocalizedString(
                    "Mapping Texture (Reconstruction)",
                    bundle: Bundle.main,
                    value: "Mapping Texture…",
                    comment: "Feedback message during the object reconstruction phase."
                )
            case .optimization:
                return NSLocalizedString(
                    "Optimizing (Reconstruction)",
                    bundle: Bundle.main,
                    value: "Optimizing…",
                    comment: "Feedback message during the object reconstruction phase."
                )
            default:
                return nil
            }
    }
}

private struct TitleView: View {
    var body: some View {
        Text(LocalizedString.processingTitle)
            .font(.largeTitle)
            .fontWeight(.bold)

    }

    private struct LocalizedString {
        static let processingTitle = NSLocalizedString(
            "Processing title (Object Capture)",
            bundle: Bundle.main,
            value: "Processing",
            comment: "Title of processing view during processing phase."
        )
    }
}
