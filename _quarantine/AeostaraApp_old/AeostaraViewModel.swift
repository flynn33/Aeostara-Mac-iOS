// Aeostara — iOS ViewModel
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.
//
// Coordinates file import, sandbox staging, and bridge calls.
// NO healing logic here — all drift/repair/rollback lives in C++ core.

import SwiftUI
import UniformTypeIdentifiers

class AeostaraViewModel: ObservableObject {
    @Published var showConfigPicker = false
    @Published var showDesiredPicker = false
    @Published var showInvariantsPicker = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var lastResult: [String: Any]?
    @Published var auditEvents: [String] = []

    @Published var configFileName: String?
    @Published var desiredFileName: String?
    @Published var invariantsFileName: String?

    private var configPath: String?
    private var desiredPath: String?
    private var invariantsPath: String?

    private let engine = AeostaraEngine()

    var canRun: Bool {
        configPath != nil && desiredPath != nil
    }

    // MARK: - File Import (copies to app sandbox)

    func handleConfigImport(_ result: Result<URL, Error>) {
        guard let url = importFile(result, prefix: "config") else { return }
        configPath = url.path
        configFileName = url.lastPathComponent
    }

    func handleDesiredImport(_ result: Result<URL, Error>) {
        guard let url = importFile(result, prefix: "desired") else { return }
        desiredPath = url.path
        desiredFileName = url.lastPathComponent
    }

    func handleInvariantsImport(_ result: Result<URL, Error>) {
        guard let url = importFile(result, prefix: "invariants") else { return }
        invariantsPath = url.path
        invariantsFileName = url.lastPathComponent
    }

    private func importFile(_ result: Result<URL, Error>, prefix: String) -> URL? {
        switch result {
        case .success(let sourceURL):
            guard sourceURL.startAccessingSecurityScopedResource() else {
                showErrorAlert("Cannot access file")
                return nil
            }
            defer { sourceURL.stopAccessingSecurityScopedResource() }

            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let workDir = docsDir.appendingPathComponent("aeostara_work", isDirectory: true)

            do {
                try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
                let destURL = workDir.appendingPathComponent("\(prefix)_\(sourceURL.lastPathComponent)")
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
                return destURL
            } catch {
                showErrorAlert("Import failed: \(error.localizedDescription)")
                return nil
            }

        case .failure(let error):
            showErrorAlert("File picker failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Engine Operations

    func runValidate() {
        guard let config = configPath, let desired = desiredPath else { return }
        var error: NSError?
        if let result = engine.validateConfig(config, desiredPath: desired,
                                              invariantsPath: invariantsPath, error: &error) {
            lastResult = result as? [String: Any]
        } else {
            showErrorAlert(error?.localizedDescription ?? "Validation failed")
        }
    }

    func runDiff() {
        guard let config = configPath, let desired = desiredPath else { return }
        var error: NSError?
        if let result = engine.diffConfig(config, desiredPath: desired,
                                          invariantsPath: invariantsPath, error: &error) {
            lastResult = result as? [String: Any]
        } else {
            showErrorAlert(error?.localizedDescription ?? "Diff failed")
        }
    }

    func runHeal() {
        guard let config = configPath, let desired = desiredPath else { return }
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let auditDir = docsDir.appendingPathComponent("audit", isDirectory: true)
        try? FileManager.default.createDirectory(at: auditDir, withIntermediateDirectories: true)
        let auditPath = auditDir.appendingPathComponent("aeostara-audit.jsonl").path

        var error: NSError?
        if let result = engine.healConfig(config, desiredPath: desired,
                                          invariantsPath: invariantsPath,
                                          auditPath: auditPath, error: &error) {
            lastResult = result as? [String: Any]
            loadAuditEvents(from: auditPath)
        } else {
            showErrorAlert(error?.localizedDescription ?? "Heal failed")
        }
    }

    private func loadAuditEvents(from path: String) {
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else { return }
        auditEvents = content.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    private func showErrorAlert(_ message: String) {
        errorMessage = message
        showError = true
    }
}
