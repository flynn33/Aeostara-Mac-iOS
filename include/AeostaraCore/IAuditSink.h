// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

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
