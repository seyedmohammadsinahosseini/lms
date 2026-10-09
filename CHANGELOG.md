# Changelog

All notable changes to LMS are documented here. The project follows semantic
versioning once signed release artifacts are published.

## [Unreleased]

### Added

- Professional LMS branding and owner-controlled Android namespace
- Portfolio screenshots and architecture diagram
- Serv00 and provider-neutral deployment packaging
- Android debug and browser runtime smoke jobs in CI

### Changed

- Unified the project, configuration namespace, package paths, session keys, and
  documentation under the permanent LMS identity
- Raised the minimum Android version to SDK 26 for Jitsi Meet SDK 13.2
- Migrated Android configuration to the AGP 9 typed Kotlin DSL

## [1.0.0-rc.1] - 2026-10-02

### Added

- Complete teacher/student class, lesson, assessment, homework, Q&A, profile,
  private-file, dashboard, Live, and isolated-demo lifecycles
- Stable `/api/v1` PHP API and preserving database migration
- Web cookie/CSRF sessions and native secure bearer-token storage
- 48 lifecycle checks, 22 security checks, and 24 Flutter tests
- Web release, Android build, signed-release, and browser-smoke workflows
