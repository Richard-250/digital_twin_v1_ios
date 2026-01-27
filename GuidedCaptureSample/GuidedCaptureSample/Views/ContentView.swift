/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The top-level app view.
*/

import SwiftUI
import os

private let logger = Logger(subsystem: GuidedCaptureSampleApp.subsystem, category: "ContentView")

/// The root of the SwiftUI View graph.
struct ContentView: View {
    @Environment(AppDataModel.self) var appModel
    @State private var showGallery = true

    var body: some View {
        Group {
            if showGallery && (appModel.state == .ready || appModel.state == .completed || appModel.state == .notSet) {
                // Show gallery when app starts or returns to ready state
                RecentScansView()
            } else {
                // Show capture/reconstruction views
                PrimaryView()
                    .onAppear(perform: {
                        UIApplication.shared.isIdleTimerDisabled = true
                    })
                    .onDisappear(perform: {
                        UIApplication.shared.isIdleTimerDisabled = false
                    })
            }
        }
        .onChange(of: appModel.state) { _, newState in
            // Show gallery when returning to ready state after completion
            if newState == .ready || newState == .completed {
                // Small delay to ensure state is stable
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await MainActor.run {
                        showGallery = true
                    }
                }
            } else if newState == .capturing || newState == .reconstructing || newState == .viewing {
                showGallery = false
            }
        }
    }
}

// MARK: - Recent Scans View (defined here since file may not be in Xcode project)
private struct RecentScansView: View {
    @Environment(AppDataModel.self) var appModel
    @State private var scanHistory = ScanHistoryManager.shared
    @State private var selectedScan: ScanMetadata?
    @State private var showNewScan = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                if scanHistory.scans.isEmpty {
                    EmptyStateView(showNewScan: $showNewScan)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(scanHistory.scans) { scan in
                                ScanThumbnailCard(scan: scan) {
                                    selectedScan = scan
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My Scans")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showNewScan = true
                        appModel.state = .ready
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(item: $selectedScan) { scan in
                // Use ModelView for now - InteractiveModelView can be added later
                ModelView(modelFile: scan.modelURL, endCaptureCallback: {})
            }
            .onChange(of: showNewScan) { _, newValue in
                if newValue {
                    appModel.state = .ready
                    showNewScan = false
                }
            }
        }
    }
}

private struct ScanThumbnailCard: View {
    let scan: ScanMetadata
    let onTap: () -> Void
    @State private var showDeleteAlert = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                    
                    // Placeholder icon
                    Image(systemName: "person.3d.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(scan.name)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Text(scan.dateCreated, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive, action: {
                showDeleteAlert = true
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Delete Scan", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                ScanHistoryManager.shared.deleteScan(scan)
            }
        } message: {
            Text("Are you sure you want to delete this scan? This action cannot be undone.")
        }
    }
}

private struct EmptyStateView: View {
    @Binding var showNewScan: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3d.fill")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Scans Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first 3D digital twin")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                showNewScan = true
            }) {
                Label("Start New Scan", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top, 20)
        }
    }
}
