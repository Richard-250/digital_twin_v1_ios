/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
View to display lighting status and requirements for optimal scanning.
*/

import SwiftUI
import RealityKit
import os

private let logger = Logger(subsystem: GuidedCaptureSampleApp.subsystem,
                            category: "LightingStatusView")

struct LightingStatusView: View {
    @Environment(AppDataModel.self) var appModel
    var session: ObjectCaptureSession
    
    var body: some View {
        if let lightingStatus = getLightingStatus() {
            HStack(spacing: 8) {
                Image(systemName: lightingStatus.icon)
                    .foregroundColor(lightingStatus.color)
                    .font(.caption)
                
                Text(lightingStatus.message)
                    .font(.caption)
                    .foregroundColor(lightingStatus.color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(lightingStatus.color.opacity(0.15))
            .cornerRadius(8)
        }
    }
    
    private func getLightingStatus() -> (icon: String, message: String, color: Color)? {
        let feedback = session.feedback
        
        // Only show lighting status when actively detecting or capturing
        guard session.state == .detecting || session.state == .capturing || session.state == .ready else {
            return nil
        }
        
        if feedback.contains(.environmentTooDark) {
            return (
                icon: "lightbulb.slash.fill",
                message: "More Light Required - Too Dark",
                color: .red
            )
        } else if feedback.contains(.environmentLowLight) {
            return (
                icon: "lightbulb.fill",
                message: "More Light Recommended",
                color: .orange
            )
        } else if session.state == .detecting || session.state == .capturing {
            // Good lighting - only show if actively scanning
            return (
                icon: "lightbulb.fill",
                message: "Lighting: Good ✓",
                color: .green
            )
        }
        
        return nil
    }
}

// Lighting requirements information view
struct LightingRequirementsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Lighting Requirements")
                .font(.headline)
                .padding(.bottom, 8)
            
            VStack(alignment: .leading, spacing: 12) {
                LightingRequirementRow(
                    icon: "lightbulb.fill",
                    title: "Optimal Lighting",
                    description: "Bright, even lighting from all directions. Avoid harsh shadows.",
                    color: .green
                )
                
                LightingRequirementRow(
                    icon: "sun.max.fill",
                    title: "Natural Light",
                    description: "Well-lit room with windows or outdoor area with diffused sunlight.",
                    color: .blue
                )
                
                LightingRequirementRow(
                    icon: "lightbulb.slash.fill",
                    title: "Avoid",
                    description: "Dark environments, direct harsh sunlight, or strong shadows.",
                    color: .red
                )
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Tips for Best Results:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                BulletPoint(text: "Use a well-lit room (indoor or outdoor)")
                BulletPoint(text: "Ensure even lighting on all sides")
                BulletPoint(text: "Avoid backlighting or strong shadows")
                BulletPoint(text: "Natural daylight works best")
                BulletPoint(text: "Minimum: Room should be clearly visible")
            }
        }
        .padding()
    }
}

private struct LightingRequirementRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.subheadline)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

