// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import SwiftUI
import UniformTypeIdentifiers
import AeostaraDomain

struct ContentView: View {
    @StateObject private var viewModel = AeostaraViewModel()
    @State private var showConfigPicker = false
    @State private var showDesiredPicker = false
    @State private var showInvariantsPicker = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - File Import Section
                Section("Import Files") {
                    Button("Import Config JSON") { showConfigPicker = true }
                        .badge(viewModel.configPath != nil ? "Loaded" : "")

                    Button("Import Desired State JSON") { showDesiredPicker = true }
                        .badge(viewModel.desiredPath != nil ? "Loaded" : "")

                    Button("Import Invariants JSON (Optional)") { showInvariantsPicker = true }
                        .badge(viewModel.invariantsPath != nil ? "Loaded" : "")
                }

                // MARK: - Actions Section
                Section("Actions") {
                    Button("Validate") { viewModel.validate() }
                        .disabled(viewModel.configPath == nil || viewModel.desiredPath == nil || viewModel.isProcessing)

                    Button("Diff") { viewModel.diff() }
                        .disabled(viewModel.configPath == nil || viewModel.desiredPath == nil || viewModel.isProcessing)

                    Button("Heal") { viewModel.heal() }
                        .disabled(viewModel.configPath == nil || viewModel.desiredPath == nil || viewModel.isProcessing)
                }

                // MARK: - Results Section
                Section("Status") {
                    Text(viewModel.statusMessage)
                        .foregroundStyle(.secondary)
                }

                if !viewModel.lastResult.isEmpty {
                    Section("Result") {
                        Text(viewModel.lastResult)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                if !viewModel.drifts.isEmpty {
                    Section("Drift Events (\(viewModel.drifts.count))") {
                        ForEach(viewModel.drifts, id: \.keyPath) { drift in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(drift.type.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(driftColor(drift.type))
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())

                                    Text(drift.keyPath)
                                        .font(.system(.body, design: .monospaced))
                                }
                                Text(drift.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Aeostara")
            .fileImporter(isPresented: $showConfigPicker, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result { viewModel.importConfig(from: url) }
            }
            .fileImporter(isPresented: $showDesiredPicker, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result { viewModel.importDesired(from: url) }
            }
            .fileImporter(isPresented: $showInvariantsPicker, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result { viewModel.importInvariants(from: url) }
            }
        }
    }

    private func driftColor(_ type: DriftType) -> Color {
        switch type {
        case .valueChanged: return .orange
        case .keyAdded: return .green
        case .keyRemoved: return .red
        }
    }
}
