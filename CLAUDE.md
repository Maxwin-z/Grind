# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Grind** is a productivity tracking application suite for Apple platforms, inspired by WakaTime. It monitors developer activity, tracking application usage, keystrokes, mouse movements, and time spent with WakaTime-style heartbeat tracking.

**Repository Structure**: Mono-repo containing two separate Xcode projects:
- `Grind-macOS/`: Full-featured macOS application (primary focus)
- `Grind-iOS/`: iOS companion app (basic template, future development)

## macOS Project (Grind-macOS)

**Location**: `Grind-macOS/`
**Bundle ID**: `me.maxwin.Grind`
**Platform**: macOS 26.1+
**UI Framework**: SwiftUI
**Database**: GRDB (SQLite wrapper)
**Status**: Phase 1 MVP backend complete, UI in progress

### Build Commands (macOS)

All commands should be run from the `Grind-macOS/` directory:

```bash
cd Grind-macOS

# Build the project
xcodebuild -project Grind.xcodeproj -scheme Grind -configuration Debug build

# Build for release
xcodebuild -project Grind.xcodeproj -scheme Grind -configuration Release build

# Clean build artifacts
xcodebuild -project Grind.xcodeproj -scheme Grind clean
```

### Core Architecture (macOS)

#### 1. Heartbeat-Based Tracking System

The app implements a WakaTime-style heartbeat algorithm with a **2-second polling loop**:

**Tracking Flow** (`ActivityMonitor.swift:109`):
1. Timer fires every 2 seconds
2. Checks current app via `AppMonitor` (NSWorkspace)
3. Gets idle time via `IdleDetector` (CGEventSource)
4. Counts keystrokes/mouse activity since last check
5. If user is active (idle < 30s): generates heartbeat
6. If user is away (idle > 120s): closes session

**Critical Rules**:
- Heartbeats only generated when idle < 30 seconds
- Session continues if heartbeat gap ≤ 120 seconds
- Session closes when user away (>120s idle)
- No over-counting during idle periods

**Idle Classification** (see `IdleDetector.swift`):
- **Typing** (<10s): Active keyboard input
- **Active** (<30s): Recent mouse/keyboard activity
- **Reading** (30-120s): Mouse movement only
- **Away** (>120s): No activity, session closed

#### 2. Data Storage (Layered Architecture)

**Database Location**: `~/Library/Application Support/Grind/grind.db`

**Layer 1: Raw Heartbeats** (`heartbeats` table)
- Generated every 2s when active
- Contains: timestamp, app info, window title, keystroke count, idle time
- Retention: 90 days
- Used for: Real-time tracking

**Layer 2: 5-Minute Blocks** (`blocks_5min` table)
- Aggregated from heartbeats every 5 minutes
- Rounded to boundaries (00, 05, 10, etc.)
- Contains: accumulated duration, typing time, keystrokes per app
- Retention: Forever (small footprint)
- Used for: Timeline visualization

**Layer 3: Daily Stats** (`daily_stats` table)
- Aggregated from time blocks
- Contains: total duration, typing duration, session counts per app
- Retention: Forever
- Used for: Dashboard statistics, historical analysis

**Performance Rule**: Query `daily_stats` for dashboards, NOT raw heartbeats

#### 3. Service Architecture (Singleton Pattern)

All monitoring services use shared singletons:

**ActivityMonitor.shared** (`Services/Monitoring/ActivityMonitor.swift`)
- Main coordinator running 2s polling loop
- Orchestrates all monitoring components
- Manages lifecycle (start/stop/pause)

**AppMonitor.shared** (`Services/Monitoring/AppMonitor.swift`)
- Tracks frontmost application (NSWorkspace)
- Captures window titles for project detection
- Provides current app metadata

**IdleDetector.shared** (`Services/Monitoring/IdleDetector.swift`)
- Wraps CGEventSource for system idle time
- Tracks keyboard and mouse separately
- Returns combined idle classification

**KeystrokeCounter.shared** (`Services/Monitoring/KeystrokeCounter.swift`)
- Global event monitor for keystroke counting
- Privacy-safe: counts only, never captures content
- Requires Accessibility permission

**MouseMovementCounter.shared** (`Services/Monitoring/MouseMovementCounter.swift`)
- Tracks mouse movements and clicks
- Provides activity intensity metrics

**HeartbeatService.shared** (`Services/Monitoring/HeartbeatService.swift`)
- Generates heartbeat records
- Applies idle detection logic
- Saves to database via repositories

**TimeBlockAggregator** (`Services/Aggregation/TimeBlockAggregator.swift`)
- Aggregates heartbeats → 5-minute blocks
- Runs periodically in background
- Maintains in-memory cache

#### 4. Database Layer (GRDB)

**DatabaseManager.shared** (`Database/DatabaseManager.swift`)
- Initializes SQLite database
- Manages schema migrations (v1-v3)
- Creates performance indexes
- Seeds default app categories (50+ apps)

**Repositories** (Repository Pattern):
- `HeartbeatRepository`: CRUD operations, queries by time range
- `TimeBlockRepository`: Aggregation queries, timeline data
- `AppCategoryRepository`: Category lookups, user overrides

**Migration History**:
- v1: Initial schema (4 core tables)
- v2: Performance indexes on timestamp/app_name
- v3: Mouse tracking columns added

### Project Structure (macOS)

```
Grind-macOS/
├── Grind.xcodeproj/
├── Grind/
│   ├── GrindApp.swift              # App entry point
│   ├── ContentView.swift           # Main UI (shows app list + stats)
│   ├── Models/                     # Data models (GRDB Codable)
│   │   ├── Heartbeat.swift         # 2s tracking unit
│   │   ├── TimeBlock.swift         # 5-min aggregation
│   │   ├── DailyStats.swift        # Daily summary
│   │   ├── AppCategory.swift       # App categorization
│   │   ├── AppInfo.swift           # Running app metadata
│   │   └── AppActivityStats.swift  # Computed statistics
│   ├── Services/
│   │   ├── Monitoring/             # Activity monitoring
│   │   │   ├── ActivityMonitor.swift
│   │   │   ├── AppMonitor.swift
│   │   │   ├── IdleDetector.swift
│   │   │   ├── KeystrokeCounter.swift
│   │   │   ├── MouseMovementCounter.swift
│   │   │   └── HeartbeatService.swift
│   │   ├── Aggregation/
│   │   │   └── TimeBlockAggregator.swift
│   │   ├── Network/                # Network communication (future)
│   │   │   ├── NetworkService.swift
│   │   │   └── NetworkMessage.swift
│   │   ├── AppService.swift        # Installed apps enumeration
│   │   └── ITerm2Service.swift     # Terminal integration (Phase 2)
│   ├── Database/
│   │   ├── DatabaseManager.swift   # GRDB setup & migrations
│   │   └── Repositories/           # Data access layer
│   │       ├── HeartbeatRepository.swift
│   │       ├── TimeBlockRepository.swift
│   │       └── AppCategoryRepository.swift
│   ├── Views/                      # SwiftUI views
│   │   └── ITerm2DetailView.swift  # Terminal session details
│   └── Utilities/
│       ├── Constants.swift         # Timing thresholds, config
│       ├── Extensions.swift        # Date/String helpers
│       └── PermissionManager.swift # Accessibility/screen recording
├── docs/                           # Comprehensive documentation
│   ├── PRD.md                      # Product requirements (CRITICAL)
│   ├── README.md                   # Project overview
│   ├── PROJECT_STRUCTURE.md        # Detailed architecture
│   ├── CLAUDE_CODE_GUIDE.md        # Implementation patterns
│   ├── QUICK_START.md              # Getting started
│   └── DEPENDENCIES.md             # Required packages
├── CLAUDE.md                       # Build commands (this file's source)
└── AGENTS.md                       # AI agent workflows
```

### Key Implementation Patterns

**Pattern: Recording Activity**
```swift
// Every 2 seconds in ActivityMonitor
let idleTime = IdleDetector.shared.getIdleTime()
if idleTime < 30 {  // Active threshold
    let heartbeat = Heartbeat(
        timestamp: Date(),
        appName: appInfo.name,
        bundleId: appInfo.bundleId,
        isTyping: idleTime < 10,
        idleSeconds: idleTime,
        keystrokeCount: KeystrokeCounter.shared.getAndResetCount()
    )
    HeartbeatRepository.shared.save(heartbeat)
}
```

**Pattern: Time Block Rounding**
```swift
// Round to 5-minute boundary (300 seconds)
let blockStart = floor(timestamp / 300) * 300
// Examples:
// 14:03:42 → 14:00:00
// 14:07:19 → 14:05:00
```

**Pattern: Querying Statistics**
```swift
// ✅ Use pre-aggregated data for dashboards
let stats = try dbQueue.read { db in
    try DailyStats
        .filter(Column("date") == today)
        .fetchAll(db)
}

// ❌ Don't query raw heartbeats for aggregates (SLOW!)
```

### macOS Permissions Required

**Accessibility** (Required):
- Keystroke/mouse monitoring
- Window title tracking
- Managed by `PermissionManager.swift`

**Screen Recording** (Optional):
- Enhanced terminal content capture (Phase 2)
- iTerm2 integration

### Development Workflow (macOS)

1. **Read the PRD First**: `docs/PRD.md` contains complete feature specifications
2. **Check Architecture**: `docs/PROJECT_STRUCTURE.md` and `docs/CLAUDE_CODE_GUIDE.md`
3. **Follow Patterns**: See "Key Implementation Patterns" section above
4. **Database Changes**: Add migrations to `DatabaseManager.swift`
5. **Privacy First**: Never store actual typed content, only counts/metadata

### Testing (macOS)

```bash
# Run from Grind-macOS/
xcodebuild test -project Grind.xcodeproj -scheme Grind
```

**Critical Test Areas**:
- Heartbeat generation logic (120s gap rule)
- Idle detection accuracy (±5 seconds)
- Time block aggregation (boundary alignment)
- Database migrations (schema integrity)

## iOS Project (Grind-iOS)

**Location**: `Grind-iOS/`
**Platform**: iOS
**Bundle ID**: TBD
**UI Framework**: SwiftUI
**Status**: Dashboard implementation complete, network sync operational

### Build Commands (iOS)

```bash
cd Grind-iOS

# Build for simulator
xcodebuild -project Grind.xcodeproj -scheme Grind -sdk iphonesimulator -configuration Debug build

# Build for device
xcodebuild -project Grind.xcodeproj -scheme Grind -sdk iphoneos -configuration Release build
```

### iOS Architecture

#### Network Client (Bonjour Service Discovery)

**NetworkClient.shared** (`Services/NetworkClient.swift`)
- Discovers macOS server via Bonjour (`_grind._tcp` service)
- Connects to macOS server on port 9527
- Receives real-time activity updates via JSON protocol
- Publishes data to SwiftUI views via Combine `@Published` properties

**Connection Flow**:
1. App starts → `startServiceDiscovery()`
2. Discovers Grind server via NWBrowser
3. Establishes TCP connection automatically
4. Receives historical stats (30 days) on connect
5. Receives real-time updates every 2 seconds

**Message Types** (see `NetworkMessage.swift`):
- `historicalStats`: Last 30 days of daily statistics
- `timeBlocks`: 5-minute block data for timeline visualization
- `realtimeActivity`: Current app, idle time, KPM updates (every 2s)
- `keystroke`: Individual keystroke events
- `dailyStatsUpdate`: Updated daily statistics
- `selectedApps`: List of apps selected in macOS app

#### Dashboard Views (MVVM Pattern)

**DashboardViewModel** (`ViewModels/DashboardViewModel.swift`)
- Central view model coordinating all dashboard data
- Subscribes to NetworkClient published properties
- Aggregates data for various chart views
- Manages connection state

**Key Views** (`Views/`):
- `DashboardView.swift`: Main container with all visualizations
- `WeeklyActivityChart.swift`: Stacked bar chart of 7-day activity by app
- `WeeklyKeystrokeChart.swift`: Stacked bar chart of 7-day keystroke counts
- `TodayTimelineView.swift`: 24-hour activity timeline (5-min blocks)
- `CurrentKeystrokeView.swift`: Real-time KPM gauge and current app
- `KeyboardVisualizerView.swift`: Visual keyboard heatmap
- `TypingSpeedGauge.swift`: Circular gauge for typing speed

#### Data Models

**KeyboardLayout** (`Models/KeyboardLayout.swift`)
- Defines keyboard key positions for visualization
- Maps key codes to visual representation

**NetworkMessage** (`Models/NetworkMessage.swift`)
- Codable structs for all message types
- Includes: `HistoricalStatsData`, `TimeBlocksData`, `RealtimeActivityData`, etc.

### iOS Project Structure

```
Grind-iOS/
├── Grind.xcodeproj/
└── Grind/
    ├── GrindApp.swift              # App entry point
    ├── ContentView.swift           # Delegates to DashboardView
    ├── Models/
    │   ├── KeyboardLayout.swift    # Keyboard visualization model
    │   └── NetworkMessage.swift    # Network protocol models
    ├── Services/
    │   └── NetworkClient.swift     # Bonjour discovery + TCP client
    ├── ViewModels/
    │   └── DashboardViewModel.swift # MVVM coordinator
    └── Views/
        ├── DashboardView.swift
        ├── WeeklyActivityChart.swift
        ├── WeeklyKeystrokeChart.swift
        ├── TodayTimelineView.swift
        ├── CurrentKeystrokeView.swift
        ├── KeyboardVisualizerView.swift
        ├── TypingSpeedGauge.swift
        ├── TypingSpeedCompactView.swift
        ├── ChartSelectionSummaryCard.swift
        └── AppLegendListView.swift
```

### iOS Development Workflow

1. **Start macOS app first**: iOS app requires running macOS server for data
2. **Ensure same network**: Both devices must be on same WiFi for Bonjour discovery
3. **Check permissions**: iOS needs Local Network permission for Bonjour
4. **Aggregate data**: Run `TimeBlockAggregator.shared.aggregateToDailyStats(for:)` on macOS to generate historical data
5. **Monitor connection**: Check green indicator in DashboardView for connection status

### iOS Permissions Required

**Local Network** (Required):
- Bonjour service discovery
- TCP connection to macOS server
- Add to Info.plist:
  ```xml
  <key>NSLocalNetworkUsageDescription</key>
  <string>Grind needs local network access to connect to your Mac</string>

  <key>NSBonjourServices</key>
  <array>
      <string>_grind._tcp</string>
  </array>
  ```

## Dependencies

**GRDB** (6.0+): SQLite wrapper with migrations
- Usage: Database operations, type-safe queries
- Import: `import GRDB`

**Logging** (Apple framework): Structured logging
- Usage: Debug logging, error tracking
- Import: `import Logging`

## Key Concepts

### Heartbeat Algorithm (WakaTime-style)

**Input**: Activity detected at timestamp T
**Logic**:
1. Check last heartbeat timestamp T_prev
2. If (T - T_prev) ≤ 120s → same session, count duration
3. If (T - T_prev) > 120s → new session, don't count gap
4. Only count time between heartbeats, never extrapolate beyond

**Example Timeline**:
```
10:00:00 - Heartbeat (typing in Xcode)
10:01:30 - Heartbeat (typing continues) → 90s counted
10:02:45 - Heartbeat (save file) → 75s counted
10:15:00 - Heartbeat (typing resumes) → 735s gap NOT counted

Total counted: 165 seconds (2m 45s)
```

### Activity Intensity Levels

Computed from events per minute in `AppActivityStats.swift`:
- **Low**: <10 events/min
- **Medium**: 10-30 events/min
- **High**: 30-60 events/min
- **Very High**: >60 events/min

Events = keystrokes + mouse movements + clicks

## Documentation Reference

**CRITICAL - Read Before Implementation**:
- `Grind-macOS/docs/PRD.md`: Complete product requirements with FR-XXX codes
- `Grind-macOS/docs/CLAUDE_CODE_GUIDE.md`: Implementation patterns and examples
- `Grind-macOS/docs/PROJECT_STRUCTURE.md`: Detailed architecture breakdown

**Quick Reference**:
- Heartbeat algorithm → PRD FR-003
- Idle detection → PRD FR-002
- Data model → PRD FR-008
- Time blocks → PRD FR-009
- App categorization → PRD FR-010
- Privacy controls → PRD FR-017, FR-018

## Common Pitfalls to Avoid

❌ **Don't** query heartbeats table for dashboard stats (performance)
✅ **Do** use `daily_stats` for aggregated queries

❌ **Don't** count time beyond last heartbeat (over-counting)
✅ **Do** apply 120-second max gap rule

❌ **Don't** store terminal content or keystrokes (privacy)
✅ **Do** store only counts and metadata

❌ **Don't** block main thread with database operations
✅ **Do** use GRDB's async read/write methods

## Performance Targets

- CPU usage: <1% average during monitoring
- Memory: <100MB RAM footprint
- Database: <500MB per year of data
- Query time: <100ms for dashboard views
- Heartbeat latency: <500ms from event to save

## Privacy Principles

1. **Local-only storage**: All data in `~/Library/Application Support/Grind/`
2. **Metadata only**: Never store actual typed content
3. **Keystroke counts**: Count events, never capture keys
4. **Window titles**: Optional, can be disabled by user
5. **Terminal content**: Phase 2 feature with strict sanitization

## Working with This Codebase

**For macOS features**:
1. Navigate to `Grind-macOS/`
2. Read relevant section in `docs/PRD.md`
3. Check existing patterns in `docs/CLAUDE_CODE_GUIDE.md`
4. Implement following singleton pattern
5. Add database migrations if schema changes
6. Update CLAUDE.md if adding build commands

**For iOS features**:
1. Navigate to `Grind-iOS/`
2. Follow MVVM pattern (ViewModels coordinate NetworkClient data)
3. Add message handlers to `NetworkClient` for new data types
4. Update `DashboardViewModel` to process and expose data to views
5. Create SwiftUI views that observe `@Published` properties
6. Coordinate with macOS `NetworkService` for protocol changes

## Current Development Phase

**macOS**: Phase 1 MVP
- ✅ Backend complete (tracking, database, aggregation)
- ✅ Network server (port 9527, Bonjour broadcasting)
- 🔄 UI in progress (ContentView shows basic app list)
- Next: Menu bar interface, enhanced desktop dashboard

**iOS**: Dashboard MVP Complete
- ✅ Bonjour service discovery and auto-connect
- ✅ Real-time data sync via TCP (JSON protocol)
- ✅ Dashboard with multiple visualizations:
  - Weekly activity/keystroke charts
  - 24-hour timeline
  - Real-time KPM gauge
  - Keyboard heatmap
- Next: App filtering, custom date ranges, notifications

## Network Communication

**Protocol**: JSON over TCP with 4-byte length prefix
**Port**: 9527
**Discovery**: Bonjour service `_grind._tcp`

**Message Flow**:
1. iOS connects → macOS sends `welcome` + `historicalStats` (30 days)
2. macOS broadcasts `realtimeActivity` every 2 seconds
3. macOS sends `keystroke` events as they occur
4. macOS sends `dailyStatsUpdate` when daily aggregation runs

**Key Files**:
- macOS: `Grind-macOS/Grind/Services/Network/NetworkService.swift`
- iOS: `Grind-iOS/Grind/Services/NetworkClient.swift`
- Protocol: `Grind-iOS/Grind/Models/NetworkMessage.swift`

See `NETWORK_CLIENT_INTEGRATION.md` for detailed protocol documentation.

## Common Development Tasks

### Testing iOS Dashboard with Real Data

The iOS dashboard requires aggregated data from macOS. To generate test data:

**Method 1: Manual aggregation trigger**
```swift
// Add to macOS ContentView.swift or create a debug button
let calendar = Calendar.current
for dayOffset in 0..<7 {
    let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
    TimeBlockAggregator.shared.aggregateToDailyStats(for: date)
}
```

**Method 2: Auto-aggregate on startup**
```swift
// Add to GrindApp.swift init()
Task {
    let calendar = Calendar.current
    for dayOffset in 0..<7 {
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
        TimeBlockAggregator.shared.aggregateToDailyStats(for: date)
    }
}
```

### Debugging Network Connection Issues

**Check macOS server status**:
```bash
# Verify server is listening
lsof -i TCP:9527

# Check Bonjour service is advertised
dns-sd -B _grind._tcp
```

**iOS connection debugging**:
- Ensure both devices on same WiFi network
- Check Local Network permission granted to iOS app
- Look for "Connected to [Mac Name]" indicator in DashboardView
- Monitor NetworkClient connection status via `@Published var connectionStatus`

**Manual connection (bypass Bonjour)**:
```swift
// In DashboardViewModel.swift
networkClient.connectToServer(host: "192.168.1.100", port: 9527)
```

### Database Inspection

```bash
# Open database with sqlite3
sqlite3 ~/Library/Application\ Support/Grind/grind.db

# Useful queries
SELECT COUNT(*) FROM heartbeats;
SELECT date, SUM(total_duration_seconds) FROM daily_stats GROUP BY date;
SELECT * FROM blocks_5min WHERE block_start >= datetime('now', '-1 day');
```

### Running Aggregation Script

For pre-existing heartbeat data:
```bash
cd Grind-macOS
./reaggregate_heartbeats.sh  # Re-aggregates all historical heartbeats
```

## Coding Standards

**Swift Version**: 5.9+
**Formatting**:
- 4-space indentation
- `UpperCamelCase` for types
- `lowerCamelCase` for properties/functions
- Use Xcode's "Re-Indent" or swift-format

**File Organization**:
- One feature per file
- Cross-cutting helpers in `Utilities/`
- Protocol-first abstractions in `Services/`

**Testing**:
- XCTest with descriptive method names
- Target ≥80% code coverage
- Mock network/database layers with stubs

**Git Commits**:
- Imperative style: "Add feature" not "Added feature"
- Prefix with platform when relevant: `macOS:`, `iOS:`
- Include testing evidence in commit body
