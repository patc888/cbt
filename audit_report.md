# CBT V1 Stability & Safety Audit Report

This report summarizes the findings of a comprehensive codebase audit conducted to identify potential crash points, data integrity issues, and architectural vulnerabilities ahead of the V1 launch.

## 🟢 Executive Summary
The CBT application is architecturally sound and follows modern SwiftUI and SwiftData best practices. Most critical crash-prone patterns (force unwraps, unsafe array access) have been avoided. However, there are a few edge cases related to **Security**, **Performance**, and **Data Reset Logic** that should be addressed to ensure a 100% stable launch.

---

## 🛑 Critical Risks (Immediate Attention)

### 1. Security: Lock Screen & Privacy Shield Bypass
**Location:** `CBTApp.swift` (`ReadyRootView`)
**Issue:** The `LockView` and `PrivacyShieldView` are presented as conditional views inside a `ZStack`.
**Impact:** In SwiftUI, `ZStack` overlays do **not** cover views presented as sheets or full-screen covers. If a user has a "New Thought Record" sheet open when the app locks, the sheet will remain visible and interactive above the lock screen.
**Recommendation:** 
- Move the lock/privacy logic to a higher level (e.g., a `.fullScreenCover` or an `.overlay` on the outermost view of the `WindowGroup`).
- Alternatively, use the `rootViewController` of the `UIWindowScene` to present the lock view in a separate `UIWindow` (more advanced but 100% secure).

### 2. Data Integrity: Reset Flow Race Condition
**Location:** `CBTApp.swift` -> `beginLocalResetFlow()`
**Issue:** The reset flow sets `launchState = .loading` and then immediately (after one `Task.yield()`) attempts to delete the SQLite store files.
**Impact:** `SwiftData` often keeps file handles open even after the view hierarchy is unmounted. If the file is still "busy" when `FileManager.removeItem` is called, the deletion will fail. The app re-opens the old store during the next bootstrap, leading to a failed reset or data inconsistency.
**Recommendation:**
- Implement a 0.3s - 0.5s delay before file deletion to allow the `ModelContainer` to fully deallocate.
- Explicitly notify the `DataResetManager` to wait for container release.

---

## 🟡 Performance & Maintenance (Recommended)

### 1. UI Stuttering: Expensive Calculations in `body`
**Location:** `HomeView.swift`, `TimelineView.swift`
**Issue:** `groupedItems` and `dailyPlanCompletionSnapshot` are computed properties or methods called directly inside the `body` property. They involve `.map`, `Dictionary(grouping:)`, and `Set` operations on potentially thousands of entries.
**Impact:** Every time a query updates (e.g., a user types in a note or saves a record), these expensive operations run on the main thread, causing frame drops and UI stuttering.
**Recommendation:**
- Use `@MemoState` or a `ViewModel` with `@Observable` to perform these calculations in the background or only when the underlying data actually changes.
- Optimize the `DailyPlan` logic to query only for the *selected date* instead of mapping the entire database.

### 2. "Floating" Model Context in Bindings
**Location:** `SettingsView.swift`
**Issue:** Some bindings (like `hapticsEnabled`) perform `try? modelContext.save()` inside the setter.
**Impact:** Errors are swallowed silently. While harmless if successful, it makes debugging persistence failures difficult.
**Recommendation:**
- Move all save logic to a dedicated `DataStore` or `ViewModel` with proper error logging.

---

## 🔵 Code Safety Assessment

| Category | Status | Notes |
| :--- | :--- | :--- |
| **Force Unwraps (`!`)** | ✅ Safe | Most uses are in `StringArrayStorage` or logical checks where nil is impossible. |
| **Array Access** | ✅ Safe | Code uses `indices.contains` or safe mapping in critical areas. |
| **Thread Safety** | ✅ Good | `HapticManager` and `BreathingPresenter` correctly use `@MainActor` or thread-safe dispatching. |
| **Dependency Risks** | 🟢 Low | Minimal 3rd party dependencies (Standard Apple Frameworks). |
| **SwiftData Recovery** | 💎 Excellent | The watchdog-protected bootstrap flow is a major strength. |

---

## 🚀 Recommended Fix Plan

1.  **[High]** Refactor `ReadyRootView` to ensure `LockView` covers all modal presentations.
2.  **[High]** Improve `beginLocalResetFlow` with a safety delay and explicit container teardown check.
3.  **[Med]** Optimize `HomeView` and `TimelineView` by offloading grouping/sorting to a background task or memoized property.
4.  **[Low]** Clean up `UsageGate` leftovers in view code (neutralize to simple on/off toggles).
