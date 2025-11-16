# Claude Code Quick Reference Guide

## 📍 How to Use This Project with Claude Code

This guide helps Claude Code understand the project structure and key decisions when implementing features.

## 🎯 Always Check First

1. **`.claudecontext`** - High-level context and key decisions
2. **`docs/PRD.md`** - Detailed requirements for the feature you're implementing
3. **This file** - Quick reference for common patterns

## 🔑 Key Architectural Principles

### The Heartbeat System (CRITICAL)

Every feature that tracks time MUST follow this pattern:

```swift
// Every 2 seconds:
let idleTime = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)

if idleTime < 30 {  // User is active
    let heartbeat = Heartbeat(
        timestamp: Date(),
        appName: activeApp.name,
        bundleId: activeApp.bundleId,
        isTyping: idleTime < 10,
        idleSeconds: idleTime
    )
    saveHeartbeat(heartbeat)
}

if idleTime > 120 {  // User is away
    closeCurrentSession()
}
```

**Rules:**

- Maximum gap between heartbeats: 120 seconds
- If gap > 120s, it's a new session (don't count the gap)
- Only count time between heartbeats, not beyond them
- See PRD FR-003 for full algorithm

### Data Layer Selection

**When to use each layer:**

| Use Case               | Table               | Why                          |
| ---------------------- | ------------------- | ---------------------------- |
| Recording activity     | `heartbeats`        | Raw, granular data           |
| Timeline visualization | `blocks_5min`       | Pre-aggregated, fast queries |
| Dashboard stats        | `daily_stats`       | Quick summaries              |
| Historical analysis    | `daily_stats`       | Efficient for long ranges    |
| Terminal tracking      | `terminal_sessions` | Separate concern             |

**Example:**

```swift
// ❌ DON'T query heartbeats for dashboard
let todayHours = heartbeats.filter(date == today).sum(duration)  // SLOW!

// ✅ DO use pre-aggregated data
let todayHours = daily_stats.filter(date == today).sum(total_duration)  // FAST!
```

## 📝 Common Implementation Patterns

### Pattern 1: Activity Monitoring Loop

```swift
class ActivityMonitor {
    private var timer: Timer?
    private let pollInterval: TimeInterval = 2.0
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(
            withTimeInterval: pollInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkActivity()
        }
    }
    
    func checkActivity() {
        // 1. Get active app
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        
        // 2. Check idle time
        let idleTime = getIdleTime()
        
        // 3. Only record if active
        if idleTime < 30 {
            recordHeartbeat(app: app, idleTime: idleTime)
        }
    }
}
```

### Pattern 2: Time Block Aggregation

```swift
func aggregateToTimeBlock(_ heartbeat: Heartbeat) {
    // Round to 5-min boundary
    let blockStart = roundTo5Minutes(heartbeat.timestamp)
    
    // Find or create block
    var block = findBlock(start: blockStart, app: heartbeat.appName)
        ?? TimeBlock(start: blockStart, app: heartbeat.appName)
    
    // Accumulate duration (max 2 seconds per heartbeat)
    block.duration += min(2.0, heartbeat.duration)
    block.keystrokeCount += heartbeat.keystrokeCount
    
    saveBlock(block)
}

func roundTo5Minutes(_ date: Date) -> Date {
    let timestamp = date.timeIntervalSince1970
    let rounded = floor(timestamp / 300) * 300
    return Date(timeIntervalSince1970: rounded)
}
```

### Pattern 3: Terminal Content Privacy

```swift
func captureTerminalContent(_ content: String) -> TerminalMetrics {
    // ❌ DON'T store actual content
    // let savedContent = content  // PRIVACY VIOLATION!
    
    // ✅ DO store only metadata
    return TerminalMetrics(
        timestamp: Date(),
        lineCount: content.components(separatedBy: .newlines).count,
        tokenCount: estimateTokens(content),
        hasLLMTool: detectLLMTool(content),
        // Hash for deduplication only, not storage
        contentHash: content.sha256()
    )
}
```

### Pattern 4: Idle Detection

```swift
func getIdleTime() -> TimeInterval {
    let mouseIdle = CGEventSource.secondsSinceLastEventType(
        .combinedSessionState,
        eventType: .mouseMoved
    )
    let keyboardIdle = CGEventSource.secondsSinceLastEventType(
        .combinedSessionState,
        eventType: .keyDown
    )
    
    // Return minimum (most recent activity)
    return min(mouseIdle, keyboardIdle)
}

func getActivityLevel() -> ActivityLevel {
    let idleTime = getIdleTime()
    
    switch idleTime {
    case ..<10:   return .typing      // Active typing
    case ..<30:   return .active      // Mouse/keyboard
    case ..<120:  return .reading     // Passive
    default:      return .away        // Idle
    }
}
```

## 🎨 UI Patterns

### SwiftUI View Structure

```swift
struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Stats Summary
            StatsHeaderView(stats: viewModel.todayStats)
            
            // Timeline Chart
            TimelineChartView(blocks: viewModel.timeBlocks)
            
            // App List
            AppListView(apps: viewModel.topApps)
        }
        .onAppear {
            viewModel.loadData()
        }
    }
}
```

### Menu Bar Icon

```swift
class MenuBarController {
    private var statusItem: NSStatusItem?
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Activity Tracker")
            button.action = #selector(menuBarClicked)
        }
    }
    
    func updateTime(_ duration: TimeInterval) {
        statusItem?.button?.title = formatDuration(duration)
    }
}
```

## 🗄️ Database Operations

### Use GRDB for Type-Safe Queries

```swift
// Define model
struct Heartbeat: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var timestamp: Date
    var appName: String
    var bundleId: String
    // ... other fields
}

// Query
let today = try dbQueue.read { db in
    try Heartbeat
        .filter(Column("timestamp") >= startOfDay)
        .fetchAll(db)
}

// Insert
try dbQueue.write { db in
    try heartbeat.insert(db)
}

// Aggregate
let stats = try dbQueue.read { db in
    try Heartbeat
        .filter(Column("timestamp") >= startOfDay)
        .select(
            Column("appName"),
            sum(Column("duration")).forKey("totalDuration")
        )
        .group(Column("appName"))
        .asRequest(of: AppStat.self)
        .fetchAll(db)
}
```

## 🔍 Feature Implementation Checklist

When implementing ANY feature, check:

- [ ] Does it affect time tracking? → Follow heartbeat algorithm
- [ ] Does it query data? → Use appropriate data layer
- [ ] Does it handle sensitive data? → Apply privacy filters
- [ ] Does it run in background? → Check performance impact
- [ ] Does it need permissions? → Handle gracefully
- [ ] Is it testable? → Write unit tests
- [ ] Does it match PRD? → Cross-reference requirements

## 📖 Where to Find Things

### Feature Requirements

- App monitoring → PRD FR-001
- Idle detection → PRD FR-002
- Heartbeat system → PRD FR-003
- Keystroke tracking → PRD FR-004
- Terminal tracking → PRD FR-005, FR-006, FR-007
- Data model → PRD FR-008, FR-009
- Privacy → PRD FR-017, FR-018, FR-019

### Technical Specs

- Database schema → PRD Section 3.3, FR-008
- UI mockups → PRD Section 6
- Architecture → PRD Section 5
- Performance requirements → PRD Section 4.1

### Example Code

- Activity monitoring → See Pattern 1 above
- Time aggregation → See Pattern 2 above
- Privacy handling → See Pattern 3 above

## ⚠️ Common Pitfalls to Avoid

### ❌ DON'T

```swift
// Don't query heartbeats for aggregates
let total = heartbeats.sum(duration)  // Slow for large datasets!

// Don't store terminal content
db.save(terminalContent)  // Privacy violation!

// Don't count time beyond heartbeats
session.duration = Date().timeIntervalSince(lastHeartbeat)  // Wrong!

// Don't block main thread
let stats = fetchStats()  // Blocks UI!
```

### ✅ DO

```swift
// Use pre-aggregated data
let total = daily_stats.sum(total_duration)  // Fast!

// Store only metadata
db.save(TerminalMetrics(lineCount: ..., tokenCount: ...))  // Safe!

// Cap duration at max gap
session.duration = min(actualDuration, 120)  // Correct!

// Use async/await
Task {
    let stats = await fetchStats()  // Non-blocking
}
```

## 🎯 Performance Targets

Keep these in mind when implementing:

| Metric            | Target      | How to Check         |
| ----------------- | ----------- | -------------------- |
| CPU Usage         | <1% average | Activity Monitor     |
| Memory            | <100MB      | Instruments          |
| Query Time        | <100ms      | Database profiler    |
| UI Response       | <200ms      | Debug logging        |
| Heartbeat Latency | <500ms      | Timestamp comparison |

## 🤔 When Unsure

1. Check `.claudecontext` for high-level guidance
2. Search PRD for the specific requirement (use PR-XXX or FR-XXX codes)
3. Look for similar existing code in the codebase
4. Follow the patterns in this guide
5. Prioritize: Privacy > Performance > Features

## 📞 Quick Links

- [Full PRD](docs/PRD.md)
- [User Stories](docs/PRD.md#2-user-stories)
- [Functional Requirements](docs/PRD.md#3-functional-requirements)
- [Technical Architecture](docs/PRD.md#5-technical-architecture)
- [Database Schema](docs/PRD.md#fr-008-data-model-architecture)

---

**Remember:** This is a privacy-focused productivity tool. When in doubt, favor user privacy over features!