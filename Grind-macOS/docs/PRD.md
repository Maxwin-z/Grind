# Product Requirements Document (PRD)

## macOS Developer Activity Tracker

**Document Version:** 1.0  
**Last Updated:** November 16, 2025  
**Product Owner:** Logic  
**Status:** Draft

---

## Executive Summary

A native macOS application that tracks developer productivity by monitoring application usage, coding activity, typing patterns, and terminal output. Similar to WakaTime but with system-level tracking capabilities and enhanced terminal/CLI tool monitoring for modern AI-assisted development workflows.

**Target Users:** Software developers, particularly those using command-line development tools (iTerm2, Claude Code, Aider, etc.)

**Key Differentiators:**

- System-level tracking (not just editor plugins)
- Terminal output and token tracking for AI coding tools
- Smart idle detection with activity classification
- Privacy-first design with local data storage
- Detailed keystroke and typing pattern analysis

---

## 1. Product Overview

### 1.1 Problem Statement

Current productivity tracking tools like WakaTime require editor plugins and don't capture the full developer workflow, especially:

- Time spent in terminals running AI coding assistants (Claude Code, Aider, etc.)
- Context switching between applications
- Reading/reviewing time vs. active coding time
- Terminal output analysis and token usage from LLM tools
- Accurate idle detection when waiting for builds, tests, or AI responses

### 1.2 Product Vision

Build a comprehensive, privacy-respecting macOS application that provides developers with deep insights into their work patterns, helping them understand where their time goes and optimize their productivity.

### 1.3 Success Metrics

- **User Engagement:** Daily active usage by 80%+ of installed base
- **Data Accuracy:** <5% deviation in time tracking compared to manual logging
- **Performance:** <1% CPU usage during monitoring
- **Privacy:** Zero data uploaded to external servers (all local)
- **Adoption:** Positive feedback on smart idle detection accuracy

---

## 2. User Stories

### 2.1 Core User Stories

**US-001: Activity Monitoring**

- As a developer, I want the app to automatically track which applications I use throughout the day so that I can see where my time goes without manual logging

**US-002: Coding Time Detection**

- As a developer, I want the app to distinguish between when I'm actively coding vs. when I just have a code editor open so that I get accurate productivity metrics

**US-003: Terminal Activity Tracking**

- As a developer using CLI tools, I want the app to track my terminal sessions and detect when I'm using AI coding assistants so that I can measure time spent with these tools

**US-004: Idle Detection**

- As a developer, I want the app to accurately detect when I'm away from my computer so that idle time doesn't inflate my productivity statistics

**US-005: Dashboard Visualization**

- As a developer, I want to view my activity in daily, weekly, and monthly views with clear visualizations so that I can identify productivity patterns

**US-006: Token Tracking**

- As a developer using AI coding tools, I want to track approximate token usage from terminal output so that I can estimate API costs and usage patterns

**US-007: Privacy Control**

- As a privacy-conscious developer, I want all my data stored locally with options to exclude sensitive applications so that my private information remains secure

### 2.2 Advanced User Stories

**US-008: Project Detection**

- As a developer working on multiple projects, I want the app to automatically detect which project I'm working on from window titles so that I can track time per project

**US-009: Goal Setting**

- As a developer, I want to set daily coding time goals and receive progress updates so that I can maintain consistent productivity

**US-010: Keystroke Analytics**

- As a developer, I want to see my typing patterns and keystrokes per minute during coding sessions so that I can understand my coding intensity

**US-011: Export Data**

- As a developer, I want to export my activity data to CSV/JSON so that I can analyze it with external tools

**US-012: Break Reminders**

- As a developer, I want optional reminders to take breaks after extended coding sessions so that I can maintain healthy work habits

---

## 3. Functional Requirements

### 3.1 Core Tracking System

#### FR-001: Application Monitoring

**Priority:** P0 (Must Have)

**Description:** Monitor active applications in real-time

**Requirements:**

- Poll active application every 2 seconds
- Capture application name, bundle ID, and window title
- Automatically categorize applications (coding, browsing, communication, etc.)
- Track foreground application focus
- Handle application switching seamlessly

**Technical Implementation:**

- Use `NSWorkspace.shared.frontmostApplication`
- Use `CGWindowListCopyWindowInfo` for window details
- Background daemon/agent running continuously
- Launch agent for auto-start on login

**Acceptance Criteria:**

- Application switches detected within 2 seconds
- No missed application changes during normal operation
- CPU usage <0.5% during monitoring
- Memory footprint <50MB

---

#### FR-002: Idle Detection System

**Priority:** P0 (Must Have)

**Description:** Accurately detect user activity vs. idle time using multi-level detection

**Requirements:**

**Idle Thresholds:**

- **Active/Typing:** <10 seconds since last keystroke
- **Active:** <30 seconds since last keyboard/mouse input
- **Passive/Reading:** 30-120 seconds since last input
- **Idle/AFK:** >120 seconds since last input

**Detection Methods:**

- Monitor keyboard events using `CGEventSource.secondsSinceLastEventType`
- Monitor mouse movements separately
- Distinguish between typing activity and mouse-only activity
- Track both input types independently

**Activity Classification:**

```
- Typing: Active keyboard input detected (<10s)
- Active: Recent mouse/keyboard activity (<30s)
- Reading: Mouse movement only (30-120s)
- Away: No activity (>120s)
```

**Technical Implementation:**

```swift
// Get system idle time
CGEventSource.secondsSinceLastEventType(
    .combinedSessionState,
    eventType: .keyDown
)
CGEventSource.secondsSinceLastEventType(
    .combinedSessionState,
    eventType: .mouseMoved
)
```

**Acceptance Criteria:**

- Idle time detection accurate within 5 seconds
- Correctly differentiates typing vs. mouse-only activity
- No false positives during legitimate work (watching videos, reading docs)
- Handles edge cases: screensaver, locked screen, display sleep

---

#### FR-003: Heartbeat Algorithm

**Priority:** P0 (Must Have)

**Description:** Implement WakaTime-style heartbeat system for accurate time tracking

**Algorithm:**

1. Record heartbeat timestamp when activity detected
2. If next heartbeat within 120 seconds → count as continuous activity
3. If gap >120 seconds → treat as separate session
4. Maximum counted duration per heartbeat: 120 seconds
5. Only count time between heartbeats, not beyond them

**Example Timeline:**

```
10:00:00 - Heartbeat (typing in Xcode)
10:01:30 - Heartbeat (typing continues)
10:02:45 - Heartbeat (save file)
10:15:00 - Heartbeat (typing resumes)

Counted time: 2 minutes 45 seconds (10:00-10:02:45)
Gap: 12 minutes 15 seconds (NOT counted as idle)
```

**Requirements:**

- Generate heartbeat on every activity check (2-second interval)
- Store heartbeat timestamp, app, activity level, keystroke count
- Apply 120-second maximum gap rule for continuous sessions
- Close session when idle threshold exceeded (>120s)
- Resume new session on activity detection

**Acceptance Criteria:**

- No over-counting during AFK periods
- Accurate session boundaries
- Handles rapid app switching correctly
- Works across sleep/wake cycles

---

#### FR-004: Keystroke Tracking

**Priority:** P0 (Must Have)

**Description:** Monitor keyboard activity to measure coding intensity

**Requirements:**

- Detect keystroke events globally
- Count keystrokes per application
- Calculate keystrokes per minute (KPM) during active coding
- Distinguish coding keystrokes from other typing (chat, email)
- Track typing duration separately from total active time

**Privacy Considerations:**

- Count keystrokes only, never capture actual key content
- No keystroke logging or recording
- Respect user privacy settings

**Technical Implementation:**

- Use `CGEventTapCreate` for global keyboard monitoring
- Requires Accessibility permission
- Increment counter on key press events only
- Reset counter per time block (5 minutes)

**Acceptance Criteria:**

- Accurate keystroke counting (±2% accuracy)
- No performance impact on typing speed
- Works across all applications
- Respects excluded applications list

---

### 3.2 Terminal Tracking System

#### FR-005: Terminal Activity Monitoring

**Priority:** P1 (Should Have)

**Description:** Track terminal usage with special handling for development CLI tools

**Requirements:**

**Supported Terminals:**

- iTerm2 (primary)
- Terminal.app
- Other terminal emulators (basic support)

**Tracking Capabilities:**

- Active terminal session duration
- Command execution detection
- Output volume measurement (lines, tokens)
- LLM tool detection (Claude Code, Aider, Cursor, etc.)

**Implementation Methods:**

**Method 1: iTerm2 Python API (Primary)**

```python
# Access session content directly
- Get visible screen content
- Monitor session output in real-time
- Track scroll buffer
- Detect active sessions
```

**Method 2: Accessibility API (Fallback)**

```swift
// For all terminals
- Monitor focused window
- Extract visible text content
- Capture terminal state every 5 seconds
```

**Acceptance Criteria:**

- Successfully captures iTerm2 content 95%+ of the time
- Falls back gracefully to Accessibility API
- Detects terminal activity vs. idle state
- Minimal performance impact on terminal responsiveness

---

#### FR-006: LLM Tool Detection & Token Tracking

**Priority:** P1 (Should Have)

**Description:** Detect AI coding assistant usage and estimate token consumption

**Supported Tools:**

- Claude Code / Claude CLI
- Aider
- GitHub Copilot CLI
- Cursor (terminal mode)
- OpenAI API CLI tools
- Custom LLM integrations

**Detection Methods:**

**Pattern Recognition:**

```regex
# Claude Code
"Claude Code|claude-code|anthropic"

# Aider
"aider|Aider version"

# Token reporting patterns
"(\d+) input.*?(\d+) output"
"tokens:.*?in=(\d+).*?out=(\d+)"
"Input tokens: (\d+).*?Output tokens: (\d+)"
```

**Tracking Metrics:**

- Session start/end times
- Approximate input tokens
- Approximate output tokens
- Commands issued count
- Files modified (if detectable)
- Estimated API cost (based on known pricing)

**Token Estimation Algorithm:**

**Method 1: Pattern Extraction**

- Parse tool output for reported token counts
- Extract from status messages
- Capture from verbose mode output

**Method 2: Content-Based Estimation**

```
For code content:
- tokens ≈ character_count / 3.0

For prose content:
- tokens ≈ character_count / 4.0

For mixed content:
- tokens ≈ word_count × 1.3
```

**Method 3: Code-Aware Estimation**

```swift
// Detect code density
if line.contains(patterns: ["{", "}", "=", ";", "function", "def"]) {
    tokens += characters / 3.0  // Code is denser
} else {
    tokens += characters / 4.0  // Prose is lighter
}
```

**Acceptance Criteria:**

- Successfully detects Claude Code sessions 90%+ of the time
- Token estimates within ±20% of actual (when verifiable)
- Captures all major LLM tool sessions
- No false positives from non-LLM terminal usage

---

#### FR-007: Terminal Content Privacy

**Priority:** P0 (Must Have)

**Description:** Handle terminal content with strict privacy controls

**Privacy Requirements:**

**Content Filtering:**

- Automatically redact API keys, tokens, passwords
- Sanitize sensitive patterns before storage
- Hash content for deduplication without storing actual text

**Redaction Patterns:**

```regex
# API Keys
(api[_-]?key|token|secret)["'\s:=]+[\w-]+

# Passwords
password["'\s:=]+\S+

# Auth tokens
(bearer|authorization)["'\s:]+[\w.-]+

# SSH keys
-----BEGIN.*?PRIVATE KEY-----
```

**Storage Options:**

**Option 1: Metadata Only (Recommended)**

```
Store:
- Line count
- Token count  
- Timestamp
- Tool name
- Content hash (for deduplication)

Do NOT store:
- Actual terminal content
- Command history
- Output text
```

**Option 2: Sanitized Content (Optional)**

```
Store sanitized content with:
- All secrets redacted
- Personal paths anonymized
- User can review before storage
```

**User Controls:**

- Toggle terminal tracking on/off
- Choose: no content / metadata only / sanitized content
- Exclude specific terminal sessions
- Clear terminal history data

**Acceptance Criteria:**

- No API keys or passwords ever stored
- User can verify no sensitive data retained
- Clear privacy settings UI
- Easy data deletion

---

### 3.3 Data Collection & Storage

#### FR-008: Data Model Architecture

**Priority:** P0 (Must Have)

**Description:** Implement multi-layer data storage for efficient queries and aggregation

**Data Layers:**

**Layer 1: Raw Heartbeats (Granular)**

```sql
CREATE TABLE heartbeats (
    id TEXT PRIMARY KEY,
    timestamp INTEGER NOT NULL,
    app_name TEXT NOT NULL,
    bundle_id TEXT NOT NULL,
    window_title TEXT,
    project_name TEXT,
    file_path TEXT,
    language TEXT,
    category TEXT NOT NULL,
    is_typing INTEGER NOT NULL,
    idle_seconds REAL NOT NULL,
    keystroke_count INTEGER DEFAULT 0
);
```

**Retention:** 90 days, then archive or delete

**Layer 2: Time Blocks (5-minute aggregates)**

```sql
CREATE TABLE blocks_5min (
    block_start INTEGER NOT NULL,
    app_name TEXT NOT NULL,
    category TEXT NOT NULL,
    active_duration INTEGER NOT NULL,
    typing_duration INTEGER NOT NULL,
    keystroke_count INTEGER NOT NULL,
    project_name TEXT,
    PRIMARY KEY (block_start, app_name)
);
```

**Retention:** Forever (small footprint)

**Layer 3: Daily Summaries**

```sql
CREATE TABLE daily_stats (
    date TEXT NOT NULL,
    app_name TEXT NOT NULL,
    category TEXT NOT NULL,
    total_duration INTEGER NOT NULL,
    typing_duration INTEGER NOT NULL,
    keystroke_count INTEGER NOT NULL,
    sessions_count INTEGER NOT NULL,
    first_active INTEGER,
    last_active INTEGER,
    PRIMARY KEY (date, app_name)
);
```

**Retention:** Forever

**Layer 4: Terminal Sessions**

```sql
CREATE TABLE terminal_sessions (
    id TEXT PRIMARY KEY,
    start_time INTEGER NOT NULL,
    end_time INTEGER,
    tool_name TEXT,
    llm_tool TEXT,
    total_lines INTEGER DEFAULT 0,
    total_tokens INTEGER DEFAULT 0,
    input_tokens INTEGER DEFAULT 0,
    output_tokens INTEGER DEFAULT 0,
    code_ratio REAL DEFAULT 0.0,
    commands_issued INTEGER DEFAULT 0
);
```

**Database Technology:** SQLite (local file storage)

**Acceptance Criteria:**

- All data stored locally (no cloud sync)
- Database file size <500MB per year
- Query performance <100ms for dashboard views
- Automatic aggregation from heartbeats to blocks
- Data integrity maintained across layers

---

#### FR-009: Time Block Aggregation

**Priority:** P0 (Must Have)

**Description:** Smallest display unit for timeline visualization

**Time Block Size:** 5 minutes (300 seconds)

**Aggregation Process:**

```
Every 5 minutes:
1. Collect all heartbeats in block (00:00-00:05, 00:05-00:10, etc.)
2. Sum active duration (max 300 seconds per block)
3. Sum typing duration
4. Sum keystroke counts
5. Determine dominant app/category
6. Store aggregate record
```

**Block Rounding:**

```swift
// Round timestamp to 5-minute boundary
let blockStart = floor(timestamp / 300) * 300
// Examples:
// 14:03:42 → 14:00:00
// 14:07:19 → 14:05:00
// 14:12:55 → 14:10:00
```

**Handling Multi-App Blocks:**

```
If multiple apps used in same 5-min block:
- Create separate block records per app
- Each block shows partial duration
- Total duration across apps ≤ 300 seconds
```

**Acceptance Criteria:**

- Timeline displays in 5-minute increments
- Blocks accurately reflect activity distribution
- No overlapping time counts
- Blocks align to clock boundaries (00, 05, 10, etc.)

---

#### FR-010: App Categorization System

**Priority:** P1 (Should Have)

**Description:** Automatically categorize applications for better insights

**Categories:**

```
- Coding (Xcode, VS Code, IntelliJ, etc.)
- Terminal (iTerm2, Terminal.app)
- Browsing (Safari, Chrome, Firefox)
- Communication (Slack, Discord, Mail, Messages)
- Design (Figma, Sketch, Photoshop)
- Documentation (Notion, Bear, Obsidian)
- Utilities (Finder, System Preferences)
- Entertainment (Spotify, YouTube, Netflix)
- Meetings (Zoom, Google Meet, Teams)
- Other
```

**Category Database:**

```sql
CREATE TABLE app_categories (
    bundle_id TEXT PRIMARY KEY,
    app_name TEXT NOT NULL,
    category TEXT NOT NULL,
    is_code_editor INTEGER DEFAULT 0,
    is_terminal INTEGER DEFAULT 0,
    user_override INTEGER DEFAULT 0
);
```

**Default Mappings:**

```swift
let defaultCategories = [
    "com.apple.dt.Xcode": "Coding",
    "com.microsoft.VSCode": "Coding",
    "com.googlecode.iterm2": "Terminal",
    "com.apple.Safari": "Browsing",
    "com.tinyspeck.slackmacgap": "Communication",
    // ... etc
]
```

**User Customization:**

- Override default categories
- Create custom categories
- Bulk category assignment

**Smart Detection:**

- Detect code editors by window title patterns
- Identify dev tools by bundle ID patterns
- Learn from user corrections

**Acceptance Criteria:**

- 95%+ apps auto-categorized correctly
- User can override any categorization
- New apps get reasonable default category
- Category changes apply retroactively (optional)

---

### 3.4 Dashboard & Visualization

#### FR-011: Menu Bar Interface

**Priority:** P0 (Must Have)

**Description:** Persistent menu bar app showing quick stats

**Display Elements:**

**Compact Mode (Default):**

```
[Icon] 4h 32m
```

**Expanded Mode (on click):**

```
Today: 4h 32m
Coding: 3h 15m
─────────────
Xcode        2h 10m
iTerm2       1h 05m
VS Code      45m
─────────────
[Open Dashboard]
[Preferences]
[Quit]
```

**Real-time Updates:**

- Update every 5 seconds when active
- Show current session time
- Highlight when tracking

**Menu Actions:**

- Click icon → Show quick stats
- Right-click → Preferences menu
- Option-click → Pause/resume tracking

**Acceptance Criteria:**

- Always visible in menu bar
- Minimal space usage (icon + time)
- Quick access to dashboard
- Shows accurate real-time stats

---

#### FR-012: Main Dashboard Window

**Priority:** P0 (Must Have)

**Description:** Comprehensive activity dashboard with multiple views

**Dashboard Tabs:**

**1. Today Tab**

```
┌─────────────────────────────────────┐
│ Today - November 16, 2025           │
├─────────────────────────────────────┤
│ Total Active: 6h 45m                │
│ Coding Time: 4h 30m                 │
│ Keystrokes: 12,456                  │
│ Idle Time: 1h 15m                   │
├─────────────────────────────────────┤
│ [Timeline Chart - 5min blocks]      │
│ ████████░░░█████░░░████████         │
├─────────────────────────────────────┤
│ Top Applications:                   │
│ 1. Xcode         3h 20m (49%)       │
│ 2. iTerm2        1h 30m (22%)       │
│ 3. Safari        45m (11%)          │
│ 4. Slack         30m (7%)           │
│ 5. VS Code       25m (6%)           │
└─────────────────────────────────────┘
```

**2. Week Tab**

```
┌─────────────────────────────────────┐
│ This Week - Nov 10-16               │
├─────────────────────────────────────┤
│ Daily Bar Chart:                    │
│ Mon ████████░ 7h 30m                │
│ Tue ██████░░░ 6h 15m                │
│ Wed █████████ 8h 45m                │
│ Thu ██████░░░ 6h 00m                │
│ Fri ████████░ 7h 15m                │
│ Sat ███░░░░░░ 2h 30m                │
│ Sun ████░░░░░ 3h 00m                │
├─────────────────────────────────────┤
│ Category Breakdown (Pie Chart)      │
│ Coding: 45% | Browsing: 25%        │
│ Terminal: 15% | Communication: 10%  │
│ Other: 5%                           │
├─────────────────────────────────────┤
│ Weekly Total: 41h 15m               │
│ Daily Average: 5h 53m               │
│ Most Productive Day: Wednesday      │
└─────────────────────────────────────┘
```

**3. Apps Tab**

```
┌─────────────────────────────────────┐
│ Applications                         │
├─────────────────────────────────────┤
│ [Today ▼] [All Categories ▼]        │
├─────────────────────────────────────┤
│ App Name      Category    Time      │
│ Xcode         Coding      3h 20m    │
│ iTerm2        Terminal    1h 30m    │
│ Safari        Browsing    45m       │
│ Slack         Comms       30m       │
│ VS Code       Coding      25m       │
│ ...                                  │
└─────────────────────────────────────┘
```

**4. Terminal Tab** (New)

```
┌─────────────────────────────────────┐
│ Terminal Activity                    │
├─────────────────────────────────────┤
│ Today's Sessions:                   │
│                                     │
│ Claude Code                         │
│ 10:30-11:45 (1h 15m)               │
│ Tokens: ~15,420 (est.)             │
│ Output: 1,234 lines                │
│                                     │
│ Aider                               │
│ 14:00-15:30 (1h 30m)               │
│ Tokens: ~8,950 (est.)              │
│ Output: 856 lines                  │
├─────────────────────────────────────┤
│ Weekly Token Usage:                 │
│ Total: ~125,000 tokens             │
│ Estimated Cost: $1.56              │
└─────────────────────────────────────┘
```

**5. Stats Tab**

```
┌─────────────────────────────────────┐
│ Statistics & Insights               │
├─────────────────────────────────────┤
│ This Week:                          │
│ Total Coding: 28h 30m              │
│ Active Typing: 18h 15m             │
│ Reading/Review: 10h 15m            │
│                                     │
│ Productivity Heatmap:               │
│       Mon Tue Wed Thu Fri Sat Sun  │
│ 06-09  ░   ░   █   ░   ░   ░   ░  │
│ 09-12  ███ ██  ███ ███ ██  ░   ░  │
│ 12-15  ██  ░   ██  █   ██  █   ░  │
│ 15-18  ███ ███ ███ ██  ███ ░   █  │
│ 18-21  ░   █   ██  ░   █   ██  ░  │
│                                     │
│ Current Streak: 12 days            │
│ Longest Streak: 45 days            │
└─────────────────────────────────────┘
```

**Charts & Visualizations:**

- Timeline chart (5-minute blocks, color-coded by app/category)
- Bar charts (daily, weekly comparisons)
- Pie charts (category distribution)
- Heatmap (productivity by hour/day)
- Line graphs (trend over time)

**Acceptance Criteria:**

- Dashboard loads in <1 second
- Smooth scrolling and interactions
- Real-time updates every 5 seconds
- Export any view to PNG/PDF
- Responsive to window resizing

---

#### FR-013: Time Range Filters

**Priority:** P1 (Should Have)

**Description:** Filter dashboard data by time ranges

**Preset Ranges:**

- Today
- Yesterday
- This Week (Mon-Sun)
- Last 7 Days
- This Month
- Last 30 Days
- All Time

**Custom Range:**

- Date picker (from - to)
- Support any date range

**Comparison Mode:**

- Compare current period to previous
- Show percentage change
- Highlight trends (up/down)

**Acceptance Criteria:**

- All views respect time range filter
- Custom ranges work for any date span
- Comparison shows meaningful insights
- Filter persists across tab switches

---

### 3.5 Advanced Features

#### FR-014: Project Detection

**Priority:** P2 (Nice to Have)

**Description:** Automatically detect and track projects from window titles and file paths

**Detection Methods:**

**Method 1: Window Title Parsing**

```
Examples:
"ViewController.swift - MyProject - Xcode"
  → Project: "MyProject"

"~/Code/client-portal/src/App.tsx - VS Code"
  → Project: "client-portal"

"[feature-branch] ~/Code/api-server (git) - iTerm2"
  → Project: "api-server"
```

**Method 2: Path Analysis**

```swift
// Extract project from common path patterns
/Users/logic/Code/PROJECT_NAME/...
/Users/logic/Projects/PROJECT_NAME/...
/Users/logic/Development/PROJECT_NAME/...

// Git repository detection
.git folder → Project root
```

**Method 3: User Manual Mapping**

```
User can define:
- Window title pattern → Project name
- Path pattern → Project name
- App + path combination → Project
```

**Project Dashboard:**

```
┌─────────────────────────────────────┐
│ Projects                            │
├─────────────────────────────────────┤
│ client-portal        28h 30m       │
│ api-server           15h 45m       │
│ mobile-app           12h 20m       │
│ internal-tools        8h 15m       │
│ (Unassigned)          5h 30m       │
└─────────────────────────────────────┘
```

**Acceptance Criteria:**

- Detect projects from Xcode, VS Code, IntelliJ
- Extract project from terminal working directory
- Handle multiple projects per day
- User can rename/merge detected projects

---

#### FR-015: Goals & Notifications

**Priority:** P2 (Nice to Have)

**Description:** Set productivity goals and receive progress notifications

**Goal Types:**

**Daily Coding Goal:**

```
Target: 6 hours coding
Current: 4h 30m (75%)
Remaining: 1h 30m
```

**Weekly Goal:**

```
Target: 35 hours active
Current: 28h 45m (82%)
On track to complete!
```

**Keystroke Goal:**

```
Target: 15,000 keystrokes/day
Current: 12,456 (83%)
```

**Streak Goals:**

```
Current Streak: 12 days
Goal: 30 days
Keep it up!
```

**Notifications:**

- Goal progress milestones (25%, 50%, 75%, 100%)
- Goal completed celebration
- Streak maintenance reminder
- Daily summary notification

**Break Reminders:**

```
"You've been coding for 2 hours"
"Time for a break? 💡"
[Dismiss] [Snooze 15m] [Disable]
```

**Acceptance Criteria:**

- Goals are customizable
- Notifications are non-intrusive
- Can disable specific notification types
- Progress visible in menu bar
- Historical goal tracking

---

#### FR-016: Data Export

**Priority:** P2 (Nice to Have)

**Description:** Export activity data for external analysis

**Export Formats:**

**CSV Export:**

```csv
timestamp,app_name,category,duration_seconds,keystroke_count,project
2025-11-16 09:00:00,Xcode,Coding,300,156,client-portal
2025-11-16 09:05:00,Xcode,Coding,300,203,client-portal
2025-11-16 09:10:00,Safari,Browsing,120,0,
```

**JSON Export:**

```json
{
  "export_date": "2025-11-16",
  "date_range": {
    "start": "2025-11-01",
    "end": "2025-11-16"
  },
  "summary": {
    "total_active_seconds": 145800,
    "total_coding_seconds": 98600,
    "total_keystrokes": 125456
  },
  "daily_stats": [...],
  "applications": [...],
  "projects": [...]
}
```

**WakaTime-Compatible Format:**

```json
// Export in WakaTime format for migration/integration
{
  "data": [
    {
      "id": "...",
      "time": 1731744000,
      "duration": 300,
      "project": "client-portal",
      "language": "Swift",
      "editor": "Xcode"
    }
  ]
}
```

**Export Options:**

- Select date range
- Select data types (apps, projects, terminal, etc.)
- Include/exclude heartbeat-level data
- Anonymize sensitive information

**Acceptance Criteria:**

- Export completes in <5 seconds for 30 days of data
- All formats are valid and parseable
- Exported data matches dashboard statistics
- Large exports (>1 year) work without crashing

---

### 3.6 Privacy & Security

#### FR-017: Privacy Controls

**Priority:** P0 (Must Have)

**Description:** Comprehensive privacy controls for sensitive data

**Excluded Applications:**

- User can mark apps to exclude from tracking
- No data collected when excluded app is active
- Common suggestions: Password managers, banking apps, private browsing

**Excluded Time Windows:**

- Define time ranges to pause tracking
- Example: "Don't track between 12:00-13:00 (lunch)"

**Window Title Privacy:**

```
Options:
1. Store full window titles
2. Store app name only (no titles)
3. Store sanitized titles (remove paths, URLs)
4. Don't store any window info
```

**Sensitive Data Filtering:**

- Automatic redaction of API keys, passwords, tokens
- Option to disable terminal content capture entirely
- Clear warning when enabling terminal tracking

**Data Deletion:**

```
- Delete data older than X days
- Delete specific date range
- Delete specific apps
- Delete all terminal data
- Nuclear option: Delete everything
```

**Acceptance Criteria:**

- Privacy settings prominently displayed
- Excluded apps immediately stop tracking
- User can verify what data is stored
- Data deletion is immediate and irreversible (with confirmation)

---

#### FR-018: Permissions Management

**Priority:** P0 (Must Have)

**Description:** Handle macOS permissions gracefully

**Required Permissions:**

**1. Accessibility (Required)**

```
Purpose: 
- Monitor active applications
- Track keyboard/mouse activity
- Detect idle time

Prompt: 
"Activity Tracker needs Accessibility permission to 
monitor your app usage and detect when you're actively 
working vs. idle."

Fallback if denied:
- Basic app tracking only (no idle detection)
- Reduced accuracy
```

**2. Screen Recording (Optional)**

```
Purpose:
- Enhanced terminal content capture
- More detailed window information

Prompt:
"For advanced terminal tracking, Activity Tracker 
needs Screen Recording permission."

Fallback if denied:
- Use Accessibility API only
- Reduced terminal tracking capability
```

**Permission Handling:**

- Request on first launch with clear explanation
- Graceful degradation if denied
- Easy re-request from preferences
- Show permission status in UI
- Link to System Preferences for manual enabling

**Acceptance Criteria:**

- Clear explanation for each permission
- App works (with limitations) without permissions
- User can change permissions anytime
- No crashes if permissions denied
- Helpful error messages guiding user

---

#### FR-019: Local Data Storage

**Priority:** P0 (Must Have)

**Description:** All data stored locally, no cloud sync

**Storage Location:**

```
~/Library/Application Support/ActivityTracker/
├── tracker.db          # Main SQLite database
├── backups/            # Automatic backups
│   ├── tracker_2025-11-16.db
│   └── tracker_2025-11-15.db
└── logs/               # Application logs
```

**Backup Strategy:**

- Automatic daily backup
- Keep last 7 backups
- Manual backup option
- Export to custom location

**Data Security:**

- Database encrypted at rest (optional)
- File permissions: user-only access
- No network transmission of tracking data
- No analytics or telemetry

**Storage Limits:**

```
Database size limits:
- Alert at 1 GB
- Suggest cleanup at 2 GB
- Auto-cleanup old data at 5 GB
```

**Acceptance Criteria:**

- All data remains on user's machine
- No network requests containing tracking data
- Backups work automatically
- User can easily locate and manage data files
- Restore from backup works flawlessly

---

## 4. Non-Functional Requirements

### 4.1 Performance

**NFR-001: System Performance**

- CPU usage: <1% average, <5% during intensive operations
- Memory footprint: <100MB RAM
- Disk I/O: Batch writes every 30 seconds to minimize SSD wear
- Application monitoring latency: <500ms to detect app switch
- Dashboard load time: <1 second for 30 days of data

**NFR-002: Database Performance**

- Query response time: <100ms for dashboard queries
- Insert performance: Handle 1,800 heartbeats/hour efficiently
- Database file size: <500MB per year of data
- Indexing: All timestamp and app_name fields indexed

**NFR-003: UI Responsiveness**

- Menu bar updates: <200ms from event to display
- Chart rendering: <500ms for timeline charts
- Scroll performance: 60fps in all views
- No UI blocking during data operations

### 4.2 Reliability

**NFR-004: Stability**

- Zero crashes during normal operation
- Graceful handling of permission denials
- Automatic recovery from database corruption
- Handles system sleep/wake cycles correctly

**NFR-005: Data Integrity**

- No data loss during app crashes
- Transactional database writes
- Automatic data validation
- Backup/restore verification

### 4.3 Usability

**NFR-006: User Experience**

- Zero-configuration startup (works out of the box)
- Intuitive UI requiring no user manual
- Clear visual feedback for all actions
- Accessible to users with disabilities (VoiceOver support)

**NFR-007: Onboarding**

- First launch tutorial (optional, skippable)
- Permission requests with clear explanations
- Sample data/demo mode for new users
- In-app help and tooltips

### 4.4 Compatibility

**NFR-008: System Requirements**

- macOS 13.0 (Ventura) or later
- Apple Silicon (M1/M2/M3) and Intel Macs
- 100MB free disk space (minimum)
- Works on multiple displays

**NFR-009: Application Compatibility**

- Tracks all GUI applications
- Special support for popular dev tools
- Compatible with multiple terminal emulators
- Works with virtualization software (Parallels, UTM)

---

## 5. Technical Architecture

### 5.1 System Components

```
┌─────────────────────────────────────────────────┐
│                  User Interface                  │
│  ┌─────────────┐  ┌──────────────────────────┐ │
│  │  Menu Bar   │  │   Dashboard Window        │ │
│  │   Widget    │  │  (SwiftUI)                │ │
│  └─────────────┘  └──────────────────────────┘ │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│              Application Layer                   │
│  ┌──────────────┐  ┌──────────────────────────┐ │
│  │   Activity   │  │    Data Aggregation       │ │
│  │   Tracker    │  │    Service                │ │
│  └──────────────┘  └──────────────────────────┘ │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│             Monitoring Services                  │
│  ┌──────────────┐  ┌──────────────────────────┐ │
│  │   App        │  │   Terminal                │ │
│  │   Monitor    │  │   Monitor                 │ │
│  └──────────────┘  └──────────────────────────┘ │
│  ┌──────────────┐  ┌──────────────────────────┐ │
│  │   Idle       │  │   Keystroke               │ │
│  │   Detector   │  │   Counter                 │ │
│  └──────────────┘  └──────────────────────────┘ │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│              Data Layer                          │
│  ┌──────────────────────────────────────────┐  │
│  │         SQLite Database                   │  │
│  │  ┌─────────────┐  ┌─────────────────────┐ │  │
│  │  │ Heartbeats  │  │   Time Blocks       │ │  │
│  │  └─────────────┘  └─────────────────────┘ │  │
│  │  ┌─────────────┐  ┌─────────────────────┐ │  │
│  │  │   Daily     │  │   Terminal Sessions │ │  │
│  │  │   Stats     │  │                     │ │  │
│  │  └─────────────┘  └─────────────────────┘ │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

### 5.2 Technology Stack

**Primary Language:** Swift 5.9+
**UI Framework:** SwiftUI
**Database:** SQLite (via GRDB.swift)
**Charts:** Swift Charts (native)
**Terminal Integration:** iTerm2 Python API, Accessibility API
**Automation:** Launch Agents (plist)
**Build System:** Xcode 15+
**Package Manager:** Swift Package Manager

**Key Dependencies:**

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
    // SQLite wrapper with migrations
    
    .package(url: "https://github.com/apple/swift-log", from: "1.5.0"),
    // Logging framework
]
```

### 5.3 Data Flow

```
User Activity
    ↓
[NSWorkspace, CGEventSource] ← System APIs
    ↓
Activity Monitor (polls every 2s)
    ↓
Heartbeat Generation
    ↓
┌─────────────────────────────┐
│  Activity Tracker Service   │
│  - Apply idle detection     │
│  - Calculate duration       │
│  - Detect typing            │
│  - Count keystrokes         │
└──────────┬──────────────────┘
           ↓
    Save to Database
           ↓
    ┌──────┴──────┐
    ↓             ↓
Heartbeats    Time Blocks (background aggregation)
    ↓             ↓
Dashboard ← Query Engine → Statistics
```

### 5.4 Background Processing

**Launch Agent (Auto-start on login):**

```xml
<!-- ~/Library/LaunchAgents/com.activitytracker.agent.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.activitytracker.agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/ActivityTracker.app/Contents/MacOS/ActivityTrackerAgent</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

**Background Tasks:**

1. Activity monitoring (continuous)
2. Time block aggregation (every 5 minutes)
3. Daily summary calculation (midnight)
4. Database cleanup (weekly)
5. Backup creation (daily)

---

## 6. User Interface Specifications

### 6.1 Menu Bar Icon States

**Icon Variations:**

```
⏱️  - Active tracking (default)
⏸️  - Paused
⚠️  - Permission error
🔴  - Recording terminal
```

**Icon with Time:**

```
⏱️ 4h 32m    (compact)
⏱️ 04:32     (time only)
```

### 6.2 Color Scheme

**Category Colors:**

```
Coding:        Blue (#007AFF)
Terminal:      Green (#34C759)
Browsing:      Orange (#FF9500)
Communication: Purple (#AF52DE)
Design:        Pink (#FF2D55)
Documentation: Teal (#5AC8FA)
Entertainment: Red (#FF3B30)
Utilities:     Gray (#8E8E93)
```

**UI Theme:**

```
Primary:   System blue
Secondary: System gray
Success:   System green
Warning:   System orange
Error:     System red
```

**Dark Mode Support:**

- Full dark mode compatibility
- Automatic theme switching
- Chart colors adjusted for dark mode

### 6.3 Typography

```
Headers:       SF Pro Display (Bold, 24pt)
Subheaders:    SF Pro Display (Semibold, 18pt)
Body:          SF Pro Text (Regular, 14pt)
Caption:       SF Pro Text (Regular, 12pt)
Menu Bar:      SF Pro Text (Medium, 13pt)
```

### 6.4 Accessibility

**VoiceOver Support:**

- All UI elements labeled
- Charts described in text
- Keyboard navigation fully supported

**Keyboard Shortcuts:**

```
⌘O    Open dashboard
⌘,    Preferences
⌘P    Pause/resume tracking
⌘E    Export data
⌘T    Today view
⌘W    Close window
```

**Display Scaling:**

- Support for all macOS text sizes
- Responsive layout adapts to window size
- Charts remain readable at all sizes

---

## 7. Development Phases

### Phase 1: MVP (Must Have - P0)

**Timeline:** 4-6 weeks

**Features:**

- ✅ Basic application monitoring
- ✅ Idle detection system
- ✅ Heartbeat algorithm implementation
- ✅ SQLite database with core tables
- ✅ Menu bar app with basic stats
- ✅ Simple dashboard (Today view)
- ✅ App categorization
- ✅ Keystroke tracking

**Deliverable:** Working time tracker with accurate activity monitoring

### Phase 2: Enhanced Tracking (Should Have - P1)

**Timeline:** 3-4 weeks

**Features:**

- ✅ Terminal activity monitoring (iTerm2 + Accessibility API)
- ✅ LLM tool detection
- ✅ Token estimation
- ✅ Time block aggregation (5-minute)
- ✅ Week/Month views in dashboard
- ✅ Category breakdown charts
- ✅ Terminal sessions tab

**Deliverable:** Full-featured dashboard with terminal tracking

### Phase 3: Advanced Features (Nice to Have - P2)

**Timeline:** 2-3 weeks

**Features:**

- ✅ Project detection
- ✅ Goals and notifications
- ✅ Break reminders
- ✅ Data export (CSV, JSON)
- ✅ Productivity heatmap
- ✅ Streak tracking

**Deliverable:** Complete productivity suite

### Phase 4: Polish & Optimization

**Timeline:** 1-2 weeks

**Focus:**

- Performance optimization
- UI refinements
- Bug fixes
- Documentation
- User testing feedback implementation

**Deliverable:** Production-ready application

---

## 8. Testing Requirements

### 8.1 Unit Tests

**Coverage Target:** 80%+

**Critical Test Areas:**

- Heartbeat generation logic
- Idle detection algorithm
- Time block aggregation
- Token estimation accuracy
- Database operations (CRUD)
- Privacy filters (redaction)

### 8.2 Integration Tests

**Scenarios:**

- App switching detection
- Terminal content capture
- Database aggregation pipeline
- Permission handling
- Sleep/wake cycle handling

### 8.3 Performance Tests

**Benchmarks:**

- Monitor CPU usage over 8-hour period (<1% average)
- Database query performance (<100ms)
- Memory leak detection
- Large dataset handling (1+ year of data)

### 8.4 User Acceptance Testing

**Test Scenarios:**

- New user onboarding
- Permission request flow
- Dashboard navigation
- Export functionality
- Privacy controls verification

---

## 9. Success Criteria & Metrics

### 9.1 Launch Criteria

**Must Meet Before v1.0 Launch:**

- ✅ Core tracking accuracy >95%
- ✅ No crashes in 100+ hours of testing
- ✅ CPU usage <1% average
- ✅ All P0 features complete
- ✅ Privacy controls fully functional
- ✅ Positive feedback from 5+ beta users

### 9.2 Key Performance Indicators

**Technical KPIs:**

- Tracking accuracy: >95%
- App crash rate: <0.1%
- Performance: <1% CPU, <100MB RAM
- Database size: <500MB/year

**User Experience KPIs:**

- Time to first value: <2 minutes
- Daily active usage: >80%
- Feature discovery: >60% use 3+ features
- Data export usage: >20% of users

**Business KPIs:**

- User retention (30-day): >70%
- Net Promoter Score: >50
- Feature requests per user: <3 (indicates completeness)

---

## 10. Risks & Mitigations

### 10.1 Technical Risks

**Risk:** macOS permission denials prevent core functionality
**Mitigation:** 

- Graceful degradation
- Clear explanations
- Alternative tracking methods

**Risk:** Performance impact on user's system
**Mitigation:**

- Aggressive optimization
- Background processing
- Minimal battery drain

**Risk:** Database corruption or data loss
**Mitigation:**

- Automatic backups
- Transaction safety
- Data validation

### 10.2 Privacy Risks

**Risk:** User concern about keystroke/screen monitoring
**Mitigation:**

- Clear privacy policy
- Local-only storage
- Transparent data handling
- Easy data deletion

**Risk:** Accidental storage of sensitive information
**Mitigation:**

- Automatic redaction
- Privacy filters
- User audit capability

### 10.3 Compatibility Risks

**Risk:** Terminal content capture fails on some terminals
**Mitigation:**

- Multiple capture methods
- Fallback mechanisms
- Clear unsupported terminal messaging

**Risk:** macOS updates break functionality
**Mitigation:**

- Conservative API usage
- Compatibility testing
- Rapid update cycle

---

## 11. Open Questions

1. **Database Retention:** Should we implement automatic cleanup of old heartbeat data (>90 days)? User preference?

2. **Token Estimation Accuracy:** Do we need integration with actual tokenizer libraries (tiktoken) for better accuracy, or is character-based estimation sufficient?

3. **Cloud Sync:** Future consideration for optional iCloud sync across devices?

4. **Team Features:** Should we consider team/organizational features (shared dashboards, team productivity)?

5. **WakaTime Import:** Should we support importing existing WakaTime data for migration?

6. **iOS Companion:** Future mobile app to view stats on iPhone/iPad?

7. **API/Webhooks:** Should we provide webhook support for integration with other productivity tools?

8. **Machine Learning:** Use ML to predict project names or categorize apps more intelligently?

---

## 12. Appendix

### 12.1 Glossary

**Heartbeat:** A timestamp record indicating user activity at a specific moment

**Time Block:** A 5-minute aggregate of activity data for visualization

**Idle Time:** Period where no keyboard/mouse input detected (>120 seconds)

**Active Time:** Time with recent user input (<30 seconds since last activity)

**Typing Time:** Time with active keyboard input (<10 seconds since last keystroke)

**Token:** Approximate unit of text processed by LLM tools (~3.5 characters)

**Session:** Continuous period of activity in single application (max 2-minute gaps)

### 12.2 References

**WakaTime Documentation:**

- https://wakatime.com/developers
- Heartbeat API specification

**macOS APIs:**

- NSWorkspace documentation
- Accessibility API reference
- CGEventSource documentation
- ScreenCaptureKit documentation

**Similar Products:**

- RescueTime
- Timing.app
- Qbserve
- ManicTime

### 12.3 Change Log

| Version | Date       | Author | Changes              |
| ------- | ---------- | ------ | -------------------- |
| 1.0     | 2025-11-16 | Logic  | Initial PRD creation |

---

## Document Approval

**Product Owner:** Logic  
**Status:** Draft  
**Next Review Date:** TBD

---

*This PRD is a living document and will be updated as requirements evolve during development.*