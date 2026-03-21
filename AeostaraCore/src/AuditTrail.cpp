// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#include "AeostaraCore/AuditTrail.h"

#include <chrono>
#include <cstdint>
#include <iomanip>
#include <sstream>

namespace Aeostara {

namespace {

std::string currentTimestamp() {
    auto now = std::chrono::system_clock::now();
    auto time_t = std::chrono::system_clock::to_time_t(now);
    std::tm tm{};
    localtime_r(&time_t, &tm);

    std::ostringstream ss;
    ss << std::put_time(&tm, "%Y-%m-%dT%H:%M:%S");
    return ss.str();
}

std::string generateEventID() {
    static uint64_t counter = 0;
    auto now = std::chrono::system_clock::now();
    auto epoch = now.time_since_epoch();
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(epoch).count();

    std::ostringstream ss;
    ss << "evt-" << std::hex << ms << "-" << std::hex << (++counter);
    return ss.str();
}

} // anonymous namespace

JsonLinesAuditTrail::JsonLinesAuditTrail(std::string auditFilePath,
                                           std::shared_ptr<IFileSystem> fs)
    : auditFilePath_(std::move(auditFilePath))
    , fs_(std::move(fs)) {}

void JsonLinesAuditTrail::record(const AuditEvent& event) {
    nlohmann::json j = event;
    std::string line = j.dump() + "\n";

    // Append to file: read existing content and append
    std::string existing;
    try {
        if (fs_->fileExists(auditFilePath_)) {
            existing = fs_->readFile(auditFilePath_);
        }
    } catch (...) {
        // File doesn't exist yet, start fresh
    }

    fs_->writeFile(auditFilePath_, existing + line);
}

std::vector<AuditEvent> JsonLinesAuditTrail::getEvents() const {
    std::vector<AuditEvent> events;

    std::string content;
    try {
        content = fs_->readFile(auditFilePath_);
    } catch (...) {
        return events;
    }

    std::istringstream stream(content);
    std::string line;
    while (std::getline(stream, line)) {
        if (line.empty()) continue;
        try {
            auto j = nlohmann::json::parse(line);
            events.push_back(j.get<AuditEvent>());
        } catch (...) {
            // Skip malformed lines
        }
    }

    return events;
}

AuditEvent JsonLinesAuditTrail::createEvent(AuditEventType type,
                                              const std::string& configFile,
                                              const nlohmann::json& details) {
    return AuditEvent{
        .eventID = generateEventID(),
        .type = type,
        .timestamp = currentTimestamp(),
        .configFile = configFile,
        .details = details
    };
}

} // namespace Aeostara
