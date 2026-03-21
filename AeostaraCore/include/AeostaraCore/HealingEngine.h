// Aeostara
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.

#pragma once

#include "AeostaraCore/IHealingEngine.h"
#include "AeostaraCore/IConfigAdapter.h"
#include "AeostaraCore/IBackupProvider.h"
#include "AeostaraCore/IAuditSink.h"
#include "AeostaraCore/IFileSystem.h"

#include <memory>

namespace Aeostara {

/// Core healing engine orchestrator implementing the 15-step healing flow.
class HealingEngine final : public IHealingEngine {
public:
    HealingEngine(std::shared_ptr<IConfigAdapter> adapter,
                  std::shared_ptr<IBackupProvider> backup,
                  std::shared_ptr<IFileSystem> fs);

    ValidationResult validate(const std::string& configPath,
                               const std::string& desiredPath,
                               const std::string& invariantsPath) override;

    DiffResult diff(const std::string& configPath,
                    const std::string& desiredPath,
                    const std::string& invariantsPath) override;

    HealResult heal(const std::string& configPath,
                    const std::string& desiredPath,
                    const std::string& invariantsPath,
                    const std::string& auditPath) override;

private:
    std::shared_ptr<IConfigAdapter> adapter_;
    std::shared_ptr<IBackupProvider> backup_;
    std::shared_ptr<IFileSystem> fs_;

    DesiredState loadDesired(const std::string& desiredPath) const;
    std::vector<Invariant> loadInvariants(const std::string& invariantsPath) const;
};

} // namespace Aeostara
