---
name: fichar-ios
description: iOS 12+, Background Fetch, Face ID, Apple restrictions. Use for iOS-specific app changes.
---

# fichAR iOS

## When to Use

- iOS build, entitlements
- Background Fetch
- Face ID / Touch ID
- Human Interface Guidelines

## Source of Truth

- `definiciones/OPTIMIZACION.md`
- `definiciones/FRONTEND.md`

## Compatibility

- **deployment target:** 12.0 (iOS 12+)
- iPhone 6 and newer

## Location

- **Region monitoring** (significant location) — not high-accuracy GPS always
- Reduce frequency when battery low

## Biometrics

- Face ID / Touch ID as second factor after password
- Biometric data never leaves device
- Use for unlocking stored token (encrypted)

## Background Fetch

- Minimal frequency
- Short tasks
- Batch operations

## Haptics

- UIImpactFeedbackGenerator
