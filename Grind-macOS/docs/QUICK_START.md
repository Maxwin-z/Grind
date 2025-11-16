# Grind - Quick Start Guide

Your Grind project structure has been initialized! Here's what to do next.

## ✅ What's Done

**Phase 1 MVP Backend (Complete):**
- ✅ Full project folder structure
- ✅ All data models (Heartbeat, TimeBlock, DailyStats, AppCategory, AppInfo)
- ✅ Database layer with GRDB (manager, migrations, repositories)
- ✅ Complete monitoring services (ActivityMonitor, IdleDetector, HeartbeatService, KeystrokeCounter, AppMonitor)
- ✅ Time block aggregation service
- ✅ Utility helpers and permission manager
- ✅ Documentation (PRD, Guide, Structure docs)

## 🔄 What's Next

### Step 1: Add Dependencies (Required)

Open Xcode and add Swift packages:

1. **Open project:**
   ```bash
   open Grind.xcodeproj
   ```

2. **Add GRDB.swift:**
   - Project → Package Dependencies → "+" button
   - URL: `https://github.com/groue/GRDB.swift`
   - Version: 6.0.0 (or later)
   - Product: GRDB

3. **Add swift-log:**
   - URL: `https://github.com/apple/swift-log`
   - Version: 1.5.0 (or later)
   - Product: Logging

See `DEPENDENCIES.md` for detailed instructions.

### Step 2: Test Build

```bash
xcodebuild -project Grind.xcodeproj -scheme Grind -configuration Debug build
```

Expected: Should compile successfully once GRDB is added.

### Step 3: Update Info.plist

Add permission descriptions for Accessibility:

```xml
<key>NSAccessibilityUsageDescription</key>
<string>Grind needs Accessibility permission to monitor your activity and track productivity metrics.</string>
```

Location: `Grind/Info.plist` (may need to create)

### Step 4: Implement UI (Next Phase)

**Priority 1: Menu Bar Interface**
Create files in `Views/MenuBar/`:
- `MenuBarController.swift` - NSStatusItem management
- `MenuBarView.swift` - Popover content
- Shows: Today's time, current app, quick stats

**Priority 2: Dashboard Window**
Create files in `Views/Dashboard/`:
- `DashboardView.swift` - Main dashboard container
- `TodayView.swift` - Today's activity view
- `TimelineChart.swift` - 5-minute block timeline
- `AppListView.swift` - List of apps with durations

**Priority 3: Update GrindApp.swift**
Wire everything together:
```swift
@main
struct GrindApp: App {
    @StateObject private var activityMonitor = ActivityMonitor.shared

    init() {
        // Initialize database
        _ = DatabaseManager.shared

        // Start monitoring
        ActivityMonitor.shared.startMonitoring()
    }

    var body: some Scene {
        MenuBarExtra("Grind", systemImage: "clock") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
```

## 🧪 Testing the Backend

Even without UI, you can test the backend:

### Test 1: Database Initialization
```swift
// In any view or main
let db = DatabaseManager.shared
print("Database initialized: \(db.getDatabaseSizeFormatted())")
```

### Test 2: Activity Monitoring
```swift
ActivityMonitor.shared.startMonitoring()

// Wait a few seconds, then check:
print(ActivityMonitor.shared.getStatistics())
```

### Test 3: Check Heartbeats
```swift
let repo = HeartbeatRepository()
let today = try? repo.getTodayHeartbeats()
print("Today's heartbeats: \(today?.count ?? 0)")
```

### Test 4: Idle Detection
```swift
let idleTime = IdleDetector.shared.getIdleTime()
let level = IdleDetector.shared.getActivityLevel()
print("Idle: \(idleTime)s, Level: \(level)")
```

## 📁 Key Files to Know

| File | Purpose | Status |
|------|---------|--------|
| `Models/Heartbeat.swift` | Core tracking data model | ✅ Done |
| `Services/Monitoring/ActivityMonitor.swift` | Main tracking coordinator | ✅ Done |
| `Database/DatabaseManager.swift` | Database setup | ✅ Done |
| `GrindApp.swift` | App entry point | 🔄 Needs update |
| `Views/MenuBar/*` | Menu bar interface | ❌ To do |
| `Views/Dashboard/*` | Dashboard views | ❌ To do |

## 🎯 Immediate Goals

1. **Today**: Add dependencies, test build
2. **This week**: Implement menu bar interface
3. **Next week**: Create basic dashboard view
4. **After that**: Test tracking for full day, iterate

## 💡 Tips

- **Start small**: Get menu bar showing basic stats first
- **Test incrementally**: Build and test after each component
- **Check permissions**: Accessibility permission is required
- **Monitor database**: Watch `~/Library/Application Support/Grind/grind.db` grow
- **Read docs**: `PROJECT_STRUCTURE.md` explains everything

## 🆘 Common Issues

**Build errors?**
- Make sure GRDB dependency is added
- Check import statements
- Verify all files are in target

**No heartbeats?**
- Grant Accessibility permission
- Verify ActivityMonitor is started
- Check idle detection (should be <30s)

**Database errors?**
- Check app sandbox settings
- Verify database directory exists
- Look at console logs for errors

## 📚 Reference Docs

- `PROJECT_STRUCTURE.md` - Complete architecture overview
- `DEPENDENCIES.md` - How to add Swift packages
- `docs/PRD.md` - Full product requirements
- `docs/CLAUDE_CODE_GUIDE.md` - Implementation patterns
- `CLAUDE.md` - Build commands

## 🚀 Ready to Code!

The backend is solid. Now bring it to life with a beautiful macOS interface!

**Start with**: Menu bar status item → Quick stats popover → Full dashboard

**Goal**: Functional time tracker showing real productivity data

---

**Questions?** Refer to PRD or implementation guide in docs/.
