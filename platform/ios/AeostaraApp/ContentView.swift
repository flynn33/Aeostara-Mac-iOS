// Aeostara — iOS Content View
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AeostaraViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Configuration Files") {
                    Button("Import Config File") {
                        viewModel.showConfigPicker = true
                    }
                    if let configName = viewModel.configFileName {
                        Label(configName, systemImage: "doc.fill")
                    }

                    Button("Import Desired State") {
                        viewModel.showDesiredPicker = true
                    }
                    if let desiredName = viewModel.desiredFileName {
                        Label(desiredName, systemImage: "doc.fill")
                    }

                    Button("Import Invariants (Optional)") {
                        viewModel.showInvariantsPicker = true
                    }
                    if let invName = viewModel.invariantsFileName {
                        Label(invName, systemImage: "doc.fill")
                    }
                }

                Section("Actions") {
                    Button("Validate") {
                        viewModel.runValidate()
                    }
                    .disabled(!viewModel.canRun)

                    Button("Diff") {
                        viewModel.runDiff()
                    }
                    .disabled(!viewModel.canRun)

                    Button("Heal") {
                        viewModel.runHeal()
                    }
                    .disabled(!viewModel.canRun)
                }

                if let result = viewModel.lastResult {
                    Section("Result") {
                        ResultView(result: result)
                    }
                }

                if !viewModel.auditEvents.isEmpty {
                    Section("Audit Trail") {
                        ForEach(viewModel.auditEvents, id: \.self) { event in
                            Text(event)
                                .font(.caption.monospaced())
                        }
                    }
                }
            }
            .navigationTitle("Aeostara")
            .fileImporter(isPresented: $viewModel.showConfigPicker,
                         allowedContentTypes: [.json]) { result in
                viewModel.handleConfigImport(result)
            }
            .fileImporter(isPresented: $viewModel.showDesiredPicker,
                         allowedContentTypes: [.json]) { result in
                viewModel.handleDesiredImport(result)
            }
            .fileImporter(isPresented: $viewModel.showInvariantsPicker,
                         allowedContentTypes: [.json]) { result in
                viewModel.handleInvariantsImport(result)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

struct ResultView: View {
    let result: [String: Any]

    var body: some View {
        if let success = result["success"] as? Bool {
            Label(success ? "Success" : "Failed",
                  systemImage: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(success ? .green : .red)
        }
        if let message = result["message"] as? String {
            Text(message)
                .font(.caption)
        }
        if let valid = result["valid"] as? Bool {
            Label(valid ? "Valid" : "Invalid",
                  systemImage: valid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(valid ? .green : .orange)
        }
        if let driftCount = result["driftCount"] as? Int, driftCount > 0 {
            Text("\(driftCount) drift(s) detected")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}
