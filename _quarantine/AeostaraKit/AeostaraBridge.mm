// Aeostara — iOS Bridge Implementation
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.
//
// Thin Objective-C++ bridge: translates Foundation types to/from C++ core.
// NO healing logic here — all drift/repair/rollback lives in C++ core.

#import "AeostaraKit.h"

#include "AeostaraCore/HealingEngine.h"
#include "AeostaraCore/JsonConfigAdapter.h"
#include "AeostaraCore/BackupManager.h"
#include "AeostaraCore/IFileSystem.h"
#include "AeostaraCore/Contracts.h"

#include <memory>
#include <string>

using namespace Aeostara;

static NSString* toNSString(const std::string& s) {
    return [NSString stringWithUTF8String:s.c_str()];
}

static std::string toStdString(NSString* _Nullable s) {
    return s ? std::string([s UTF8String]) : std::string();
}

static NSDictionary* driftEventToDict(const DriftEvent& e) {
    return @{
        @"keyPath": toNSString(e.keyPath),
        @"type": toNSString(to_string(e.type)),
        @"description": toNSString(e.description)
    };
}

static NSDictionary* auditEventToDict(const AuditEvent& e) {
    return @{
        @"eventID": toNSString(e.eventID),
        @"type": toNSString(to_string(e.type)),
        @"timestamp": toNSString(e.timestamp),
        @"configFile": toNSString(e.configFile)
    };
}

static NSError* makeError(const std::string& message) {
    return [NSError errorWithDomain:@"com.aeostara.engine"
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: toNSString(message)}];
}

@implementation AeostaraEngine {
    std::shared_ptr<IFileSystem> _fs;
    std::shared_ptr<IConfigAdapter> _adapter;
    std::shared_ptr<IBackupProvider> _backup;
    std::shared_ptr<IHealingEngine> _engine;
}

- (nonnull instancetype)init {
    self = [super init];
    if (self) {
        _fs = std::make_shared<DefaultFileSystem>();
        _adapter = std::make_shared<JsonConfigAdapter>(_fs);
        _backup = std::make_shared<BackupManager>(_fs);
        _engine = std::make_shared<HealingEngine>(_adapter, _backup, _fs);
    }
    return self;
}

- (nullable NSDictionary *)validateConfig:(nonnull NSString *)configPath
                              desiredPath:(nonnull NSString *)desiredPath
                           invariantsPath:(nullable NSString *)invariantsPath
                                    error:(NSError * _Nullable * _Nullable)error {
    try {
        auto result = _engine->validate(
            toStdString(configPath),
            toStdString(desiredPath),
            toStdString(invariantsPath));

        NSMutableArray* errors = [NSMutableArray array];
        for (const auto& e : result.errors) {
            [errors addObject:toNSString(e)];
        }

        NSMutableArray* drifts = [NSMutableArray array];
        for (const auto& d : result.drifts) {
            [drifts addObject:driftEventToDict(d)];
        }

        return @{
            @"valid": @(result.valid),
            @"errors": errors,
            @"driftCount": @(result.drifts.size()),
            @"drifts": drifts
        };
    } catch (const std::exception& ex) {
        if (error) *error = makeError(ex.what());
        return nil;
    }
}

- (nullable NSDictionary *)diffConfig:(nonnull NSString *)configPath
                          desiredPath:(nonnull NSString *)desiredPath
                       invariantsPath:(nullable NSString *)invariantsPath
                                error:(NSError * _Nullable * _Nullable)error {
    try {
        auto result = _engine->diff(
            toStdString(configPath),
            toStdString(desiredPath),
            toStdString(invariantsPath));

        NSMutableArray* drifts = [NSMutableArray array];
        for (const auto& d : result.drifts) {
            [drifts addObject:driftEventToDict(d)];
        }

        NSMutableArray* actions = [NSMutableArray array];
        for (const auto& a : result.proposedPlan.actions) {
            [actions addObject:@{
                @"keyPath": toNSString(a.keyPath),
                @"actionType": toNSString(to_string(a.actionType)),
                @"rationale": toNSString(a.rationale)
            }];
        }

        return @{
            @"driftCount": @(result.drifts.size()),
            @"drifts": drifts,
            @"proposedPlan": @{
                @"planID": toNSString(result.proposedPlan.planID),
                @"actions": actions,
                @"requiresBackup": @(result.proposedPlan.requiresBackup)
            }
        };
    } catch (const std::exception& ex) {
        if (error) *error = makeError(ex.what());
        return nil;
    }
}

- (nullable NSDictionary *)healConfig:(nonnull NSString *)configPath
                          desiredPath:(nonnull NSString *)desiredPath
                       invariantsPath:(nullable NSString *)invariantsPath
                            auditPath:(nullable NSString *)auditPath
                                error:(NSError * _Nullable * _Nullable)error {
    try {
        auto result = _engine->heal(
            toStdString(configPath),
            toStdString(desiredPath),
            toStdString(invariantsPath),
            toStdString(auditPath));

        NSMutableArray* auditEvents = [NSMutableArray array];
        for (const auto& e : result.auditEvents) {
            [auditEvents addObject:auditEventToDict(e)];
        }

        NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:@{
            @"success": @(result.success),
            @"message": toNSString(result.message),
            @"verification": @{
                @"success": @(result.verification.success),
                @"verifiedAt": toNSString(result.verification.verifiedAt)
            },
            @"auditEvents": auditEvents
        }];

        if (result.rollback.has_value()) {
            dict[@"rollback"] = @{
                @"planID": toNSString(result.rollback->planID),
                @"backupFilePath": toNSString(result.rollback->backupFilePath),
                @"originalFilePath": toNSString(result.rollback->originalFilePath)
            };
        }

        return dict;
    } catch (const std::exception& ex) {
        if (error) *error = makeError(ex.what());
        return nil;
    }
}

@end
