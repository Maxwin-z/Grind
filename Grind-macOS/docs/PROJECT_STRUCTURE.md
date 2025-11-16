# Grind - Project Structure

This document describes the complete project structure that has been initialized for the Grind macOS activity tracker.

## Phase 1 MVP - What's Been Created

This initialization covers **Phase 1 (MVP)** features from the PRD:
- ✅ Basic application monitoring
- ✅ Idle detection system
- ✅ Heartbeat algorithm implementation
- ✅ SQLite database with core tables
- ✅ App categorization
- ✅ Keystroke tracking
- 🔄 Menu bar app (pending UI implementation)
- 🔄 Simple dashboard (pending UI implementation)

## Directory Structure

```
Grind/
├── Models/                          # Data models
│   ├── Heartbeat.swift             # Raw activity record (every 2s when active)
│   ├── TimeBlock.swift             # 5-minute aggregated blocks
│   ├── DailyStats.swift            # Daily summary statistics
│   ├── AppCategory.swift           # App categorization system
│   └── AppInfo.swift               # Running application info
│
├── Services/                        # Business logic services
│   ├── Monitoring/                 # Activity monitoring services
│   │   ├── ActivityMonitor.swift  # Main coordinator (2s polling loop)
│   │   ├── AppMonitor.swift       # Tracks active application
│   │   ├── IdleDetector.swift     # Detects idle time (FR-002)
│   │   ├── KeystrokeCounter.swift # Global keystroke counting
│   │   └── HeartbeatService.swift # Heartbeat generation (FR-003)
│   │
│   ├── Aggregation/                # Data aggregation services
│   │   └── TimeBlockAggregator.swift # Aggregates to 5-min blocks
│   │
│   └── Database/                   # Database services
│       └── (empty - using Database/ at root level)
│
├── Database/                        # Database layer (GRDB)
│   ├── DatabaseManager.swift       # Database setup & migrations
│   ├── Repositories/               # Data access repositories
│   │   ├── HeartbeatRepository.swift    # Heartbeat CRUD
│   │   ├── TimeBlockRepository.swift    # Time block CRUD
│   │   └── AppCategoryRepository.swift  # Category management
│   │
│   └── Migrations/                 # Database migrations
│       └── (managed by DatabaseManager)
│
├── Views/                           # SwiftUI views (TODO)
│   ├── Dashboard/                  # Main dashboard views
│   ├── MenuBar/                    # Menu bar interface
│   └── Components/                 # Reusable UI components
│
├── ViewModels/                      # View models for views (TODO)
│
├── Utilities/                       # Helper utilities
│   ├── Constants.swift             # App-wide constants
│   ├── Extensions.swift            # Common extensions
│   └── PermissionManager.swift     # macOS permission handling
│
├── Resources/                       # Additional resources
│
├── Assets.xcassets/                 # App assets
│   ├── AppIcon.appiconset/
│   └── AccentColor.colorset/
│
├── GrindApp.swift                   # App entry point
└── ContentView.swift                # Main view (TODO: update)
```

## Key Components Explained

### 1. Models Layer

**Heartbeat.swift** - The fundamental tracking unit
- Generated every 2 seconds when user is active
- Stores: app name, bundle ID, window title, category, idle time, keystroke count
- Implements GRDB `FetchableRecord` and `PersistableRecord`
- Per PRD FR-008 schema

**TimeBlock.swift** - 5-minute aggregation
- Smallest unit for timeline visualization
- Rounds timestamps to 5-minute boundaries
- Accumulates duration, typing time, keystrokes
- Per PRD FR-009

**DailyStats.swift** - Daily summaries
- Pre-aggregated statistics per app/category
- Enables fast dashboard queries
- Stores total duration, typing duration, session counts

**AppCategory.swift** - App classification
- Maps bundle IDs to categories (Coding, Browsing, etc.)
- 50+ default app mappings (Xcode, VS Code, Safari, etc.)
- Supports user overrides
- Per PRD FR-010

### 2. Services Layer

**ActivityMonitor.swift** - Main coordinator
- Runs 2-second polling loop (PRD FR-001)
- Coordinates all monitoring components
- Manages start/stop lifecycle
- Provides statistics and status

**IdleDetector.swift** - Idle time tracking
- Uses `CGEventSource.secondsSinceLastEventType`
- Tracks keyboard and mouse separately
- Classifies activity levels:
  - Typing: <10s idle
  - Active: <30s idle
  - Reading: 30-120s idle
  - Away: >120s idle
- Per PRD FR-002

**HeartbeatService.swift** - Heartbeat generation
- Implements WakaTime-style heartbeat algorithm
- Max 120-second gap for continuous sessions
- Generates heartbeats only when active (<30s idle)
- Manages session boundaries
- Per PRD FR-003

**KeystrokeCounter.swift** - Global keystroke tracking
- Uses `CGEvent.tapCreate` for global monitoring
- Privacy-safe: counts only, never records keys
- Requires Accessibility permission
- Per PRD FR-004

**AppMonitor.swift** - Application tracking
- Detects active foreground app
- Captures window titles for project detection
- Integrates with AppCategory for classification
- Handles app switching events

**TimeBlockAggregator.swift** - Data aggregation
- Aggregates heartbeats into 5-minute blocks
- Uses in-memory cache with periodic flush
- Runs in background to avoid UI blocking
- Per PRD FR-009

### 3. Database Layer

**DatabaseManager.swift** - SQLite management
- Initializes database at `~/Library/Application Support/Grind/grind.db`
- Manages migrations using GRDB `DatabaseMigrator`
- Creates tables: heartbeats, blocks_5min, daily_stats, app_categories
- Seeds default app categories
- Creates indexes for performance
- Per PRD FR-008

**Repositories** - Data access pattern
- HeartbeatRepository: CRUD for heartbeat records
- TimeBlockRepository: CRUD + aggregations for time blocks
- AppCategoryRepository: Category lookups and management
- Encapsulates all database operations

### 4. Utilities

**Constants.swift** - Configuration values
- Timing thresholds (2s poll, 30s active, 120s away)
- Database settings
- UI update intervals

**Extensions.swift** - Common helpers
- Date extensions (startOfDay, endOfDay, formatting)
- TimeInterval formatting (asHoursMinutes, asMinutesSeconds)
- String utilities

**PermissionManager.swift** - Permission handling
- Checks Accessibility permission status
- Requests permissions with user prompts
- Provides fallback explanations
- Per PRD FR-018

## How It Works - The Tracking Flow

```
1. User launches app
   ↓
2. ActivityMonitor.startMonitoring()
   ↓
3. Start 2-second timer
   ↓
4. Every 2 seconds:
   ├─ AppMonitor.updateCurrentApp()
   │  └─ Get frontmost app + window title
   │
   ├─ IdleDetector.getIdleTime()
   │  └─ Check keyboard/mouse idle time
   │
   ├─ If idle < 30s (active):
   │  ├─ HeartbeatService.recordActivity()
   │  ├─ Generate Heartbeat
   │  ├─ Save to database
   │  └─ TimeBlockAggregator.aggregateHeartbeat()
   │     └─ Accumulate into 5-min block
   │
   └─ If idle > 120s (away):
      └─ Close current session
```

## Database Schema

### heartbeats
```sql
CREATE TABLE heartbeats (
    id TEXT PRIMARY KEY,
    timestamp DATETIME NOT NULL,
    appName TEXT NOT NULL,
    bundleId TEXT NOT NULL,
    windowTitle TEXT,
    projectName TEXT,
    filePath TEXT,
    language TEXT,
    category TEXT NOT NULL,
    isTyping BOOLEAN NOT NULL,
    idleSeconds REAL NOT NULL,
    keystrokeCount INTEGER DEFAULT 0
);
```

### blocks_5min
```sql
CREATE TABLE blocks_5min (
    blockStart DATETIME NOT NULL,
    appName TEXT NOT NULL,
    category TEXT NOT NULL,
    activeDuration INTEGER NOT NULL,
    typingDuration INTEGER NOT NULL,
    keystrokeCount INTEGER NOT NULL,
    projectName TEXT,
    PRIMARY KEY (blockStart, appName)
);
```

### daily_stats
```sql
CREATE TABLE daily_stats (
    date TEXT NOT NULL,
    appName TEXT NOT NULL,
    category TEXT NOT NULL,
    totalDuration INTEGER NOT NULL,
    typingDuration INTEGER NOT NULL,
    keystrokeCount INTEGER NOT NULL,
    sessionsCount INTEGER NOT NULL,
    firstActive DATETIME,
    lastActive DATETIME,
    PRIMARY KEY (date, appName)
);
```

### app_categories
```sql
CREATE TABLE app_categories (
    bundleId TEXT PRIMARY KEY,
    appName TEXT NOT NULL,
    category TEXT NOT NULL,
    isCodeEditor BOOLEAN DEFAULT FALSE,
    isTerminal BOOLEAN DEFAULT FALSE,
    userOverride BOOLEAN DEFAULT FALSE
);
```

## What's Left to Implement (Phase 1 MVP)

### High Priority
1. **Menu Bar Interface** (`Views/MenuBar/`)
   - Menu bar status item with icon
   - Quick stats popover (today's time, top apps)
   - Start/stop/pause controls
   - Link to dashboard

2. **Dashboard Views** (`Views/Dashboard/`)
   - Today view with timeline chart
   - App list with durations
   - Basic statistics (total time, keystrokes, etc.)

3. **Update GrindApp.swift**
   - Initialize DatabaseManager
   - Start ActivityMonitor on launch
   - Handle app lifecycle (quit, sleep/wake)

4. **Info.plist Configuration**
   - Add permission usage descriptions
   - Configure background modes if needed

### Medium Priority
5. **ViewModels** (`ViewModels/`)
   - DashboardViewModel
   - MenuBarViewModel
   - TodayStatsViewModel

6. **Testing**
   - Unit tests for heartbeat algorithm
   - Unit tests for idle detection
   - Integration tests for database operations

## Next Steps

### Step 1: Add Dependencies
1. Open `Grind.xcodeproj` in Xcode
2. Add Swift packages per `DEPENDENCIES.md`:
   - GRDB.swift (6.0.0+)
   - swift-log (1.5.0+)

### Step 2: Build & Fix Compilation
```bash
xcodebuild -project Grind.xcodeproj -scheme Grind -configuration Debug build
```

Fix any compilation errors that arise.

### Step 3: Implement UI Components
- Start with menu bar interface
- Then create basic dashboard view
- Connect to existing services

### Step 4: Test Permissions
- Test Accessibility permission flow
- Verify keystroke counting works
- Test idle detection accuracy

### Step 5: Test Tracking
- Run app for extended period
- Verify heartbeats are being recorded
- Check database is growing correctly
- Verify time blocks are aggregating

## References

- **PRD**: `docs/PRD.md` - Complete product requirements
- **Guide**: `docs/CLAUDE_CODE_GUIDE.md` - Implementation patterns
- **Dependencies**: `DEPENDENCIES.md` - Required packages
- **Project Config**: `CLAUDE.md` - Build commands and settings

## Architecture Principles

1. **Privacy First** - Never store actual typed content, only counts
2. **Heartbeat Algorithm** - Max 120s gaps, no over-counting
3. **Layered Data** - Heartbeats → Blocks → Daily Stats (query performance)
4. **Background Processing** - Aggregation happens async, UI stays responsive
5. **Graceful Degradation** - App works (with limitations) if permissions denied

---

**Status**: Phase 1 MVP Backend Complete
**Next**: UI Implementation + Testing
**Target**: Functional time tracker with basic dashboard
