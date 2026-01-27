/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Bottom overlay button implementation for capture overlay view.
*/

import RealityKit
import SwiftUI
import os

private let logger = Logger(subsystem: GuidedCaptureSampleApp.subsystem, category: "BottomOverlayButtons")

struct BottomOverlayButtons: View, OverlayButtons {
    @Environment(AppDataModel.self) var appModel
    var session: ObjectCaptureSession
    @Binding var hasDetectionFailed: Bool
    @Binding var showCaptureModeGuidance: Bool
    @Binding var showTutorialView: Bool
    var rotationAngle: Angle

    var body: some View {
        HStack(alignment: .center) {
            HStack {
                switch session.state {
                    case .ready:
                        HelpButton()
                            .frame(width: 30)
                    case .detecting:
                        HStack(spacing: 12) {
                            LockBoundingBoxButton(session: session)
                            ResetBoundingBoxButton(session: session)
                        }
                    default:
                        NumOfImagesButton(session: session)
                            .rotationEffect(rotationAngle)
                        Spacer()
                }
            }
            .frame(maxWidth: .infinity)

            if !isCapturingStarted(state: session.state) {
                CaptureButton(session: session,
                              hasDetectionFailed: $hasDetectionFailed,
                              showTutorialView: $showTutorialView)
                    .frame(width: 200)
            }

            HStack {
                switch session.state {
                    case .ready:
                    if appModel.orbit == .orbit1 {
                        CaptureModeButton(session: session,
                                          showCaptureModeGuidance: $showCaptureModeGuidance)
                            .frame(width: 30)
                    }
                    case .detecting:
                        AutoDetectionStateView(session: session)
                    default:
                        HStack {
                            Spacer()
                            AutoCaptureToggle(session: session)
                            ManualShotButton(session: session)
                        }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .transition(.opacity)
    }
}

@MainActor
private struct CaptureButton: View {
    @Environment(AppDataModel.self) var appModel
    var session: ObjectCaptureSession
    @Binding var hasDetectionFailed: Bool
    @Binding var showTutorialView: Bool

    var body: some View {
        Button(
            action: {
                performAction()
            },
            label: {
                Text(buttonLabel)
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 25)
                    .padding(.vertical, 20)
                    .background(.blue)
                    .clipShape(Capsule())
            })
    }

    private var buttonLabel: String {
        if session.state == .ready {
            switch appModel.captureMode {
                case .object:
                    return LocalizedString.continue
                case .area:
                    return LocalizedString.startCapture
            }
        } else {
            if !appModel.isObjectFlipped {
                return LocalizedString.startCapture
            } else {
                return LocalizedString.continue
            }
        }
    }

    private func performAction() {
        if session.state == .ready {
            switch appModel.captureMode {
            case .object:
                hasDetectionFailed = !(session.startDetecting())
            case .area:
                session.startCapturing()
            }
        } else if case .detecting = session.state {
            session.startCapturing()
        }
    }

    struct LocalizedString {
        static let startCapture = NSLocalizedString(
            "Start Capture (Object Capture)",
            bundle: Bundle.main,
            value: "Start Capture",
            comment: "Title for the Start Capture button on the object capture screen.")
        static let `continue` = NSLocalizedString(
            "Continue (Object Capture, Capture)",
            bundle: Bundle.main,
            value: "Continue",
            comment: "Title for the Continue button on the object capture screen.")
    }
}

private struct AutoDetectionStateView: View {
    @Environment(AppDataModel.self) var appModel
    var session: ObjectCaptureSession
    
    @State private var isAnimating = false
    
    // Computed property for detection state
    private var isDetected: Bool {
        !session.feedback.contains(.objectNotDetected)
    }

    var body: some View {
        VStack(spacing: 6) {
            let imageName = isDetected ? "person.crop.circle.fill" : "person.crop.circle.badge.questionmark"
            
            ZStack {
                // Pulsing background circle when detecting
                if !isDetected {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .opacity(isAnimating ? 0.0 : 0.5)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
                
                Image(systemName: imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(5)
                    .frame(width: 30)
            }
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                let text = isDetected ? 
                    (appModel.isBoundingBoxLocked ? "Locked" : "Detected") : 
                    "Detecting..."
                Text(text)
                    .frame(width: 90)
                    .font(.footnote)
                    .opacity(0.7)
                    .fontWeight(.semibold)
            }
        }
        .foregroundColor(isDetected ? (appModel.isBoundingBoxLocked ? .green : .white) : .orange)
        .fontWeight(.semibold)
        .padding(.bottom, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 15)
        .onAppear {
            if !session.feedback.contains(.objectNotDetected) {
                isAnimating = false
            } else {
                isAnimating = true
            }
        }
        .onChange(of: session.feedback.contains(.objectNotDetected)) { _ in
            if session.feedback.contains(.objectNotDetected) {
                isAnimating = true
            } else {
                isAnimating = false
            }
        }
    }
}

private struct LockBoundingBoxButton: View {
    @Environment(AppDataModel.self) var appModel
    var session: ObjectCaptureSession

    var body: some View {
        Button(
            action: {
                appModel.isBoundingBoxLocked.toggle()
                
                if appModel.isBoundingBoxLocked {
                    logger.log("Bounding box manually locked by user")
                } else {
                    logger.log("Bounding box unlocked by user - will auto-lock when person is detected")
                }
            },
            label: {
                VStack(spacing: 6) {
                    Image(systemName: appModel.isBoundingBoxLocked ? "lock.fill" : "lock.open")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30)

                    if UIDevice.current.userInterfaceIdiom == .pad {
                        Text(LocalizedString.lockBox)
                            .font(.footnote)
                            .opacity(0.7)
                    }
                }
                .foregroundColor(appModel.isBoundingBoxLocked ? .green : .white)
                .fontWeight(.semibold)
            })
        .padding(.bottom, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 15)
        .disabled(session.feedback.contains(.objectNotDetected) && !appModel.isBoundingBoxLocked)
        .opacity((session.feedback.contains(.objectNotDetected) && !appModel.isBoundingBoxLocked) ? 0.5 : 1.0)
    }

    struct LocalizedString {
        static let lockBox = NSLocalizedString(
            "Lock Box (Object Capture)",
            bundle: Bundle.main,
            value: "Lock Box",
            comment: "Title for the Lock Box button on the object capture screen.")
    }
}

private struct ResetBoundingBoxButton: View {
    @Environment(AppDataModel.self) var appModel
    var session: ObjectCaptureSession

    var body: some View {
        Button(
            action: {
                // Unlock box first, then reset detection
                appModel.isBoundingBoxLocked = false
                // Use the person detection service's reset method if available
                appModel.personDetectionService.resetDetection()
                session.resetDetection()
                logger.log("Reset bounding box - detection restarted")
            },
            label: {
                VStack(spacing: 6) {
                    Image("ResetBbox")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30)

                    if UIDevice.current.userInterfaceIdiom == .pad {
                        Text(LocalizedString.resetBox)
                            .font(.footnote)
                            .opacity(0.7)
                    }
                }
                .foregroundColor(.white)
                .fontWeight(.semibold)
            })
        .padding(.bottom, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 15)
    }

    struct LocalizedString {
        static let resetBox = NSLocalizedString(
            "Reset Box (Object Capture)",
            bundle: Bundle.main,
            value: "Reset Box",
            comment: "Title for the Reset Box button on the object capture screen."
        )
    }
}

private struct ManualShotButton: View {
    var session: ObjectCaptureSession

    var body: some View {
        Button(
            action: {
                session.requestImageCapture()
            },
            label: {
                Text(Image(systemName: "button.programmable"))
                    .font(.largeTitle)
                    .foregroundColor(session.canRequestImageCapture ? .white : .gray)
            }
        )
        .disabled(!session.canRequestImageCapture)
    }
}

private struct HelpButton: View {
    @Environment(AppDataModel.self) var appModel
    @State private var showHelpPageView: Bool = false

    var body: some View {
        Button(action: {
            logger.log("\(LocalizedString.help) button clicked!")
            withAnimation {
                showHelpPageView = true
            }
        }, label: {
            Image(systemName: "questionmark.circle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22)
                .foregroundColor(.white)
                .padding(20)
                .contentShape(.rect)
        })
        .padding(-20)
        .sheet(isPresented: $showHelpPageView) {
            HelpPageView(showHelpPageView: $showHelpPageView)
                .padding()
        }
        .onChange(of: showHelpPageView) {
            appModel.setShowOverlaySheets(to: showHelpPageView)
        }
    }

    struct LocalizedString {
        static let help = NSLocalizedString(
            "Help (Object Capture)",
            bundle: Bundle.main,
            value: "Help",
            comment: "Title for the Help button on the object capture screen to show the tutorial pages.")
    }
}

private struct CaptureModeButton: View {
    @Environment(AppDataModel.self) var appModel
    var session: ObjectCaptureSession
    @Binding var showCaptureModeGuidance: Bool
    @State private var captureModeGuidanceTimer: Timer? = nil

    var body: some View {
        Button(action: {
            switch appModel.captureMode {
                case .object:
                    DispatchQueue.main.async {
                        logger.log("Area mode selected!")
                        appModel.captureMode = .area
                    }
                case .area:
                    DispatchQueue.main.async {
                        logger.log("Object mode selected!")
                        appModel.captureMode = .object
                    }
            }
            logger.log("Setting showCaptureModeGuidance to true")
            withAnimation {
                showCaptureModeGuidance = true
            }
            // Cancel the previous scheduled timer.
            if captureModeGuidanceTimer != nil {
                captureModeGuidanceTimer?.invalidate()
                captureModeGuidanceTimer = nil
            }
            captureModeGuidanceTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) {_ in
                logger.log("Setting showCaptureModeGuidance to false")
                withAnimation {
                    showCaptureModeGuidance = false
                }
            }
        }, label: {
            VStack {
                switch appModel.captureMode {
                    case .area:
                        Image(systemName: "circle.dashed")
                            .resizable()
                    case .object:
                        Image(systemName: "cube")
                            .resizable()
                }
            }
            .aspectRatio(contentMode: .fit)
            .frame(width: 22)
            .foregroundStyle(.white)
            .padding(20)
            .contentShape(.rect)
        })
        .padding(-20)
    }
}

private struct NumOfImagesButton: View {
    @Environment(AppDataModel.self) var appModel
    var session: ObjectCaptureSession

    @State private var showInfo: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    // Server processing supports up to 500 images
    private let serverMaxImages = 500

    var body: some View {
        Button(action: {
            showInfo = true
        },
               label: {
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .padding([.horizontal, .top], 4)
                    .overlay(alignment: Alignment(horizontal: .trailing, vertical: .top)) {
                        if session.feedback.contains(.overCapturing) {
                            Image(systemName: "circle.fill")
                                .foregroundColor(.orange)
                                .font(.caption2)
                        }
                    }
                // Show server limit (500) instead of on-device limit for server processing
                Text(String(format: LocalizedString.numOfImages,
                            session.numberOfShotsTaken,
                            serverMaxImages))
                .font(.footnote)
                .fontWidth(.condensed)
                .fontDesign(.rounded)
                .bold()
            }
            .foregroundColor(.white)
        })
        .popover(isPresented: $showInfo) {
            VStack(alignment: .leading, spacing: 20) {
                Label(LocalizedString.photoLimit, systemImage: "photo")
                    .font(.headline)
                Text(String(format: LocalizedString.createModelLimits,
                            AppDataModel.minNumImages,
                            serverMaxImages))
                Text(LocalizedString.captureMoreServer)
            }
            .foregroundStyle(colorScheme == .light ? .black : .white)
            .padding()
            .frame(idealWidth: UIDevice.current.userInterfaceIdiom == .pad ? 300 : .infinity)
            .presentationDetents([.fraction(0.3)])
        }
    }

    struct LocalizedString {
        static let numOfImages = NSLocalizedString(
            "%d/%d (Format, # of Images)",
            bundle: Bundle.main,
            value: "%d/%d",
            comment: "Images taken over maximum number of images.")
        static let photoLimit = NSLocalizedString(
            "Photo limit (Object Capture)",
            bundle: Bundle.main,
            value: "Photo limit",
            comment: "Title for photo limit popover.")
        static let createModelLimits = NSLocalizedString(
            "To create a model on device you need a minimum of %d images and a maximum of %d images. (Object Capture)",
            bundle: Bundle.main,
            value: "To create a model on device you need a minimum of %d images and a maximum of %d images.",
            comment: "Text to explain the photo limits in object capture.")
        static let captureMore = NSLocalizedString(
            "You can capture more than %d images and process them on your Mac. (Object Capture)",
            bundle: Bundle.main,
            value: "You can capture more than %d images and process them on your Mac.",
            comment: "Text to explain the photo limit in object capture.")
        static let captureMoreServer = NSLocalizedString(
            "Server processing supports up to 500 images. Continue capturing to improve model quality. (Object Capture)",
            bundle: Bundle.main,
            value: "Server processing supports up to 500 images. Continue capturing to improve model quality.",
            comment: "Text explaining server processing supports up to 500 images.")
    }
}

private struct AutoCaptureToggle: View {
    var session: ObjectCaptureSession

    var body: some View {
        Button(action: {
            session.isAutoCaptureEnabled.toggle()
        }, label: {
            HStack(spacing: 5) {
                if session.isAutoCaptureEnabled {
                    Image(systemName: "a.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 15)
                        .foregroundStyle(.black)
                } else {
                    Image(systemName: "circle.slash.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 15)
                        .foregroundStyle(.black)
                }
                Text("Auto")
                    .font(.footnote)
                    .foregroundStyle(.black)
            }
            .padding(.all, 5)
            .background(.ultraThinMaterial)
            .background(session.isAutoCaptureEnabled ? .white : .clear)
            .cornerRadius(15)
        })
    }
}
