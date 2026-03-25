// Logger+App.swift
// Apple Logger extension for SweepPic app
//
// Usage:
//   import OSLog      // Required for Logger type
//   import AppCore    // Required for Logger extension members
//
//   Logger.viewer.debug("scale: \(scale)")
//   Logger.pipeline.error("thumbnail load failed: \(error)")

import OSLog

extension Logger {
    /// App bundle identifier as subsystem (fallback for test environment)
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.sweeppic.appcore"

    // =============================================
    // MARK: - Feature
    // =============================================

    /// Viewer: photo/video viewer, swipe, zoom, overlay
    public static let viewer       = Logger(subsystem: subsystem, category: "Viewer")

    /// Albums: album list, album grid, trash album
    public static let albums       = Logger(subsystem: subsystem, category: "Albums")

    /// SimilarPhoto: similarity analysis, face comparison
    public static let similarPhoto = Logger(subsystem: subsystem, category: "SimilarPhoto")

    /// Cleanup: auto-cleanup, quality analysis, benchmarks
    public static let cleanup      = Logger(subsystem: subsystem, category: "Cleanup")

    /// Transition: zoom transition animations
    public static let transition   = Logger(subsystem: subsystem, category: "Transition")

    // =============================================
    // MARK: - Infrastructure
    // =============================================

    /// Pipeline: image pipeline, thumbnail cache, preload
    public static let pipeline     = Logger(subsystem: subsystem, category: "Pipeline")

    /// Performance: scroll hitch, timing, liquid glass
    public static let performance  = Logger(subsystem: subsystem, category: "Performance")

    /// Analytics: TelemetryDeck, Supabase, event tracking
    public static let analytics    = Logger(subsystem: subsystem, category: "Analytics")

    /// CoachMark: onboarding coach marks (A, C, D, replay)
    public static let coachMark    = Logger(subsystem: subsystem, category: "CoachMark")

    // =============================================
    // MARK: - App
    // =============================================

    /// App: AppDelegate, SceneDelegate, lifecycle
    public static let app          = Logger(subsystem: subsystem, category: "App")

    /// Debug: button inspector, debug-only features ("debug" conflicts with instance method)
    public static let appDebug     = Logger(subsystem: subsystem, category: "Debug")
}
