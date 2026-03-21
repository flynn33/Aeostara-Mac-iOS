// Aeostara — iOS Bridging Header
// Copyright (c) 2026 James Daley. All Rights Reserved.
// Proprietary and Confidential.
//
// This Objective-C++ header bridges the C++ healing engine
// to Swift via the AeostaraKit framework.

#ifndef AeostaraKit_h
#define AeostaraKit_h

#import <Foundation/Foundation.h>

/// Thin Objective-C++ wrapper around the C++ HealingEngine.
/// All drift/repair/rollback logic lives in C++ core — this bridge
/// only translates between Foundation types and C++ types.
@interface AeostaraEngine : NSObject

- (nonnull instancetype)init;

/// Validate config against desired state. Returns dict with keys:
/// valid (BOOL), errors (NSArray), driftCount (NSNumber), violations (NSArray)
- (nullable NSDictionary *)validateConfig:(nonnull NSString *)configPath
                              desiredPath:(nonnull NSString *)desiredPath
                           invariantsPath:(nullable NSString *)invariantsPath
                                    error:(NSError * _Nullable * _Nullable)error;

/// Diff config against desired state. Returns dict with keys:
/// driftCount (NSNumber), drifts (NSArray), proposedPlan (NSDictionary)
- (nullable NSDictionary *)diffConfig:(nonnull NSString *)configPath
                          desiredPath:(nonnull NSString *)desiredPath
                       invariantsPath:(nullable NSString *)invariantsPath
                                error:(NSError * _Nullable * _Nullable)error;

/// Heal config drift. Returns dict with keys:
/// success (BOOL), message (NSString), plan (NSDictionary),
/// verification (NSDictionary), auditEvents (NSArray)
- (nullable NSDictionary *)healConfig:(nonnull NSString *)configPath
                          desiredPath:(nonnull NSString *)desiredPath
                       invariantsPath:(nullable NSString *)invariantsPath
                            auditPath:(nullable NSString *)auditPath
                                error:(NSError * _Nullable * _Nullable)error;

@end

#endif /* AeostaraKit_h */
