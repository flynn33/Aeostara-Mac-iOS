// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#pragma once

#include "AeostaraCore/IAuditSink.h"
#include "AeostaraCore/IFileSystem.h"

#include <memory>
#include <string>

namespace Aeostara {

/// JSON Lines (.jsonl) audit trail implementation.
class JsonLinesAuditTrail final : public IAuditSink {
public:
    JsonLinesAuditTrail(std::string auditFilePath, std::shared_ptr<IFileSystem> fs);

    void record(const AuditEvent& event) override;
    std::vector<AuditEvent> getEvents() const override;

    /// Create an AuditEvent with a generated event ID and current timestamp.
    static AuditEvent createEvent(AuditEventType type,
                                   const std::string& configFile,
                                   const nlohmann::json& details = {});

private:
    std::string auditFilePath_;
    std::shared_ptr<IFileSystem> fs_;
};

} // namespace Aeostara
