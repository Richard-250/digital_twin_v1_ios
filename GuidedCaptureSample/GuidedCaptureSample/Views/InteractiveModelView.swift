/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Interactive 3D model viewer with clothing selection (t-shirt and trousers).
*/

import SwiftUI
import RealityKit
import ARKit
import os

private let logger = Logger(subsystem: GuidedCaptureSampleApp.subsystem,
                            category: "InteractiveModelView")

struct InteractiveModelView: View {
    let scan: ScanMetadata
    @Environment(\.dismiss) var dismiss
    @State private var selectedClothing: ClothingType = .none
    @State private var modelEntity: ModelEntity?
    
    enum ClothingType: String, CaseIterable {
        case none = "None"
        case tshirt = "T-Shirt"
        case trousers = "Trousers"
        case both = "Both"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 3D Model View
                Model3DView(
                    modelURL: scan.modelURL,
                    selectedClothing: $selectedClothing,
                    modelEntity: $modelEntity
                )
                
                // Clothing Selection UI
                VStack {
                    Spacer()
                    
                    ClothingSelectorView(
                        selectedClothing: $selectedClothing,
                        modelEntity: $modelEntity
                    )
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding()
                }
            }
            .navigationTitle(scan.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct Model3DView: UIViewRepresentable {
    let modelURL: URL
    @Binding var selectedClothing: InteractiveModelView.ClothingType
    @Binding var modelEntity: ModelEntity?
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.environment.background = .color(.systemGray6)
        
        // Load the model
        Task {
            do {
                let entity = try await ModelEntity(contentsOf: modelURL)
                await MainActor.run {
                    // Center and scale the model
                    let bounds = entity.visualBounds(recursive: true, relativeTo: nil)
                    let center = bounds.center
                    entity.position = -center
                    
                    // Scale to fit in view
                    let maxDimension = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
                    let scale: Float = 1.5 / maxDimension
                    entity.scale = [scale, scale, scale]
                    
                    // Create anchor
                    let anchor = AnchorEntity()
                    anchor.addChild(entity)
                    arView.scene.addAnchor(anchor)
                    
                    modelEntity = entity
                    applyClothing(to: entity, type: selectedClothing)
                }
            } catch {
                logger.error("Failed to load model: \(error.localizedDescription)")
            }
        }
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update clothing when selection changes
        if let entity = modelEntity {
            applyClothing(to: entity, type: selectedClothing)
        }
    }
    
    private func applyClothing(to entity: ModelEntity, type: InteractiveModelView.ClothingType) {
        // Remove existing clothing
        entity.children.forEach { child in
            if child.name.contains("tshirt") || child.name.contains("trousers") {
                child.removeFromParent()
            }
        }
        
        // Add new clothing based on selection
        switch type {
        case .none:
            break // No clothing
        case .tshirt:
            addTShirt(to: entity)
        case .trousers:
            addTrousers(to: entity)
        case .both:
            addTShirt(to: entity)
            addTrousers(to: entity)
        }
    }
    
    private func addTShirt(to entity: ModelEntity) {
        // Create a simple t-shirt geometry - slightly larger to cover torso
        let tshirtMesh = MeshResource.generateBox(width: 0.45, height: 0.55, depth: 0.25)
        
        // Create material (blue t-shirt)
        var material = SimpleMaterial()
        material.color = .init(tint: .systemBlue, texture: nil)
        material.metallic = 0.0
        material.roughness = 0.8
        
        let tshirtEntity = ModelEntity(mesh: tshirtMesh, materials: [material])
        tshirtEntity.name = "tshirt"
        
        // Position t-shirt on upper body (adjust based on model bounds)
        let bounds = entity.visualBounds(recursive: true, relativeTo: nil)
        // Position at upper third of the model
        tshirtEntity.position = [0, bounds.center.y + bounds.extents.y * 0.2, 0]
        
        entity.addChild(tshirtEntity)
    }
    
    private func addTrousers(to entity: ModelEntity) {
        // Create simple trousers geometry - two separate legs for better appearance
        let leftLegMesh = MeshResource.generateBox(width: 0.15, height: 0.45, depth: 0.15)
        let rightLegMesh = MeshResource.generateBox(width: 0.15, height: 0.45, depth: 0.15)
        
        // Create material (dark gray/black trousers)
        var material = SimpleMaterial()
        material.color = .init(tint: .black, texture: nil)
        material.metallic = 0.0
        material.roughness = 0.9
        
        let leftLeg = ModelEntity(mesh: leftLegMesh, materials: [material])
        leftLeg.name = "trousers_left"
        
        let rightLeg = ModelEntity(mesh: rightLegMesh, materials: [material])
        rightLeg.name = "trousers_right"
        
        // Position trousers on lower body
        let bounds = entity.visualBounds(recursive: true, relativeTo: nil)
        let legY = bounds.center.y - bounds.extents.y * 0.15
        
        leftLeg.position = [-0.1, legY, 0]
        rightLeg.position = [0.1, legY, 0]
        
        entity.addChild(leftLeg)
        entity.addChild(rightLeg)
    }
}

private struct ClothingSelectorView: View {
    @Binding var selectedClothing: InteractiveModelView.ClothingType
    @Binding var modelEntity: ModelEntity?
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Select Clothing")
                .font(.headline)
                .padding(.bottom, 8)
            
            HStack(spacing: 12) {
                ClothingButton(
                    title: "T-Shirt",
                    icon: "tshirt.fill",
                    isSelected: selectedClothing == .tshirt || selectedClothing == .both
                ) {
                    if selectedClothing == .tshirt {
                        selectedClothing = .none
                    } else if selectedClothing == .both {
                        selectedClothing = .trousers
                    } else {
                        selectedClothing = selectedClothing == .trousers ? .both : .tshirt
                    }
                }
                
                ClothingButton(
                    title: "Trousers",
                    icon: "figure.walk",
                    isSelected: selectedClothing == .trousers || selectedClothing == .both
                ) {
                    if selectedClothing == .trousers {
                        selectedClothing = .none
                    } else if selectedClothing == .both {
                        selectedClothing = .tshirt
                    } else {
                        selectedClothing = selectedClothing == .tshirt ? .both : .trousers
                    }
                }
            }
        }
    }
}

private struct ClothingButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .cornerRadius(12)
        }
    }
}

