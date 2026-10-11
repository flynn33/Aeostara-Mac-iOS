// Aeostara
// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.

#pragma once

#include "AeostaraCore/Contracts.h"

#include <string>
#include <vector>

namespace Aeostara {

/// Abstract audit trail interface.
class IAuditSink {
public:
    virtual void record(const AuditEvent& event) = 0;
    virtual std::vector<AuditEvent> getEvents() const = 0;

    virtual ~IAuditSink() = default;
};

} // namespace Aeostara
