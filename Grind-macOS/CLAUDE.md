# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Grind is a macOS productivity tracking application built with SwiftUI targeting macOS 26.1+. It monitors user activity across applications, tracking keystrokes, mouse movements, and time spent in each app with WakaTime-style heartbeat tracking.

**Bundle Identifier**: `me.maxwin.Grind`
**Development Team**: BS4GBZN537
**Platform**: macOS only
**Dependencies**: GRDB (SQLite), Logging

## Build Commands

### Build the project
```bash
xcodebuild -project Grind.xcodeproj -scheme Grind -configuration Debug build
```

### Build for release
```bash
xcodebuild -project Grind.xcodeproj -scheme Grind -configuration Release build
```

### Run the app (build and run)
```bash
xcodebuild -project Grind.xcodeproj -scheme Grind -configuration Debug build && open build/Debug/Grind.app
```

### Clean build artifacts
```bash
xcodebuild -project Grind.xcodeproj -scheme Grind clean
```

## Project Structure

```
Grind-macOS/
├── Grind.xcodeproj/
└── Grind/
    ├── GrindApp.swift                          # App entry point, initializes ActivityMonitor
    ├── ContentView.swift                       # Main UI with app list and activity stats
    ├── Models/                                 # Data models
    │   ├── Heartbeat.swift                     # Core tracking unit (generated every 2s)
    │   ├── TimeBlock.swift                     # 5-minute aggregated blocks
    │   ├── DailyStats.swift                    # Daily summary statistics
    │   ├── AppCategory.swift                   # App categorization
    │   ├── AppInfo.swift                       # Current app metadata
    │   ├── MacApp.swift                        # Installed apps model
    │   └── AppActivityStats.swift              # Computed activity statistics
    ├── Services/
    │   ├── AppService.swift                    # Fetches installed apps
    │   ├── Monitoring/
    │   │   ├── ActivityMonitor.swift           # Main coordinator (2s polling loop)
    │   │   ├── HeartbeatService.swift          # Heartbeat generation and saving
    │   │   ├── AppMonitor.swift                # Tracks active application
    │   │   ├── IdleDetector.swift              # System idle time tracking
    │   │   ├── KeystrokeCounter.swift          # Global keystroke monitoring
    │   │   └── MouseMovementCounter.swift      # Mouse activity tracking
    │   └── Aggregation/
    │       └── TimeBlockAggregator.swift       # Aggregates heartbeats into 5-min blocks
    ├── Database/
    │   ├── DatabaseManager.swift               # GRDB setup, migrations, schema
    │   └── Repositories/
    │       ├── HeartbeatRepository.swift       # Heartbeat CRUD and queries
    │       ├── TimeBlockRepository.swift       # Time block operations
    │       └── AppCategoryRepository.swift     # Category management
    └── Utilities/
        ├── PermissionManager.swift             # Accessibility/screen recording permissions
        ├── Constants.swift                     # App-wide constants
        └── Extensions.swift                    # Swift extensions
```

## Architecture

### Core Tracking System (WakaTime-style)

The app implements a heartbeat-based activity tracking system:

1. **2-Second Polling Loop** (`ActivityMonitor.swift:109`)
   - Timer runs every 2 seconds when app is active
   - Checks current app, idle time, keystroke/mouse activity
   - Generates heartbeats when user is active (idle < 30s)
   - Skips when user is away (idle > 120s)

2. **Heartbeat Generation** (`HeartbeatService.swift:31`)
   - Creates `Heartbeat` records with app info, window title, project name
   - Includes keystroke count, mouse movements/clicks since last heartbeat
   - Determines typing state based on idle time
   - Saves to database via `HeartbeatRepository`

3. **Activity Monitoring Components**
   - `AppMonitor`: Uses NSWorkspace to track frontmost app and window title
   - `IdleDetector`: Wraps CGEventSource to get system idle time
   - `KeystrokeCounter`: Global event monitor for keystroke counting
   - `MouseMovementCounter`: Tracks mouse movements and clicks

4. **Data Aggregation**
   - `TimeBlockAggregator`: Rolls up heartbeats into 5-minute blocks
   - Heartbeats → 5-min blocks → Daily stats (hierarchical aggregation)

### Database Schema (GRDB/SQLite)

**Database Location**: `~/Library/Application Support/Grind/grind.db`

**Core Tables** (see `DatabaseManager.swift:96-162`):
- `heartbeats`: Raw 2-second activity snapshots (90-day retention)
- `blocks_5min`: 5-minute aggregated time blocks
- `daily_stats`: Daily summary per app
- `app_categories`: User-configurable app categorization

**Migrations** (`DatabaseManager.swift:65-92`):
- v1: Initial schema
- v2: Performance indexes
- v3: Mouse tracking columns

### UI Architecture

**Main UI** (`ContentView.swift`):
- Split view: App list (sidebar) + Active app details (detail pane)
- Updates every 2s via Timer
- Shows all installed apps with running status
- Displays real-time activity stats for current app

**Data Flow**:
- `GrindApp` → starts `ActivityMonitor.shared.startMonitoring()`
- `ContentView` → polls `AppMonitor` and `HeartbeatRepository` every 2s
- Activity stats computed on-the-fly from heartbeat aggregations

### Singleton Pattern

All monitoring services use shared singletons to ensure single source of truth:
- `ActivityMonitor.shared`
- `AppMonitor.shared`
- `HeartbeatService.shared`
- `IdleDetector.shared`
- `KeystrokeCounter.shared`
- `MouseMovementCounter.shared`
- `DatabaseManager.shared`

## Key Concepts

### Idle Time Classification (FR-002)
- **Typing** (<10s): Active keyboard input
- **Active** (<30s): Recent mouse/keyboard activity
- **Reading** (30-120s): Mouse movement only
- **Away** (>120s): No activity, session closed

### Session Management (FR-003)
- Sessions continue if heartbeat gap ≤ 120 seconds
- Sessions close when user goes away (>120s idle)
- Heartbeats only generated when idle < 30s

### Activity Intensity Levels
Computed from events per minute:
- Low, Medium, High, Very High (see `AppActivityStats.swift`)

## Dependencies

- **GRDB**: SQLite wrapper for database operations
- **Logging**: Apple's structured logging framework

## Permissions Required

- **Accessibility**: Required for keystroke/mouse monitoring
- **Screen Recording**: Required for window title tracking

Managed by `PermissionManager.swift`

## Key Build Settings

- **Swift Version**: 5.0
- **Deployment Target**: macOS 26.1
- **Code Signing**: Automatic
- **App Sandbox**: Enabled
- **Hardened Runtime**: Enabled
- **SwiftUI Previews**: Enabled
- **File System Sync**: PBXFileSystemSynchronizedRootGroup (auto-adds Swift files)
