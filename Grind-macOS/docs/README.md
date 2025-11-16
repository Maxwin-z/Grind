# Activity Tracker for macOS

A native macOS application for tracking developer productivity and activity patterns.

## 🎯 Overview

Track your coding time, application usage, and terminal activity with precision. Similar to WakaTime but with system-level tracking and AI coding tool integration.

**Key Features:**
- 📊 Automatic activity tracking across all applications
- ⌨️ Keystroke and typing pattern analysis
- 🖥️ Terminal session and LLM tool monitoring
- 🎨 Beautiful native macOS dashboard
- 🔒 Privacy-first: all data stored locally
- 📈 Daily, weekly, monthly insights

## 📚 Documentation

**Essential Reading:**
- **[Product Requirements Document (PRD)](docs/PRD.md)** - Complete feature specifications and requirements
- **[Architecture Guide](docs/ARCHITECTURE.md)** - Technical architecture and design decisions *(to be created)*
- **[Development Guide](docs/DEVELOPMENT_GUIDE.md)** - Setup and contribution guidelines *(to be created)*

## 🚀 Quick Start

```bash
# Clone the repository
git clone <your-repo-url>
cd activity-tracker

# Open in Xcode
open ActivityTracker.xcodeproj

# Build and run
⌘R
```

## 🏗️ Project Structure

```
ActivityTracker/
├── docs/                   # 📄 All documentation
│   ├── PRD.md             # Product requirements
│   ├── ARCHITECTURE.md    # Technical specs
│   └── ...
├── src/
│   ├── ActivityTracker/   # Main app code
│   │   ├── Models/
│   │   ├── Views/
│   │   ├── Services/
│   │   └── Utilities/
│   └── ActivityTrackerTests/
├── .claudecontext         # Claude Code context file
└── README.md              # This file
```

## 🛠️ Tech Stack

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **Database:** SQLite (GRDB.swift)
- **Charts:** Swift Charts
- **Terminal Integration:** iTerm2 Python API + Accessibility API

## 📋 Development Phases

- [x] **Phase 1:** Core tracking & idle detection *(Current)*
- [ ] **Phase 2:** Terminal tracking & LLM detection
- [ ] **Phase 3:** Advanced features (projects, goals)
- [ ] **Phase 4:** Polish & optimization

See [PRD.md](docs/PRD.md#7-development-phases) for detailed timeline.

## 🔐 Privacy

- ✅ All data stored locally on your Mac
- ✅ No cloud sync or external servers
- ✅ Automatic redaction of sensitive information
- ✅ Granular privacy controls
- ✅ Easy data deletion

## 🤝 Contributing

When implementing features:
1. **Read the PRD first:** Check [docs/PRD.md](docs/PRD.md) for requirements
2. **Follow architecture:** Reference `.claudecontext` for key decisions
3. **Write tests:** Maintain 80%+ coverage
4. **Performance matters:** Keep CPU < 1%, RAM < 100MB

## 📊 Key Metrics & Goals

- **Tracking Accuracy:** >95%
- **Performance:** <1% CPU average
- **Memory:** <100MB RAM
- **Database Size:** <500MB/year

## 🐛 Known Issues

See [GitHub Issues](../../issues) for current bugs and feature requests.

## 📝 License

[Your License Here]

## 🙏 Acknowledgments

Inspired by [WakaTime](https://wakatime.com), [RescueTime](https://www.rescuetime.com), and [Timing.app](https://timingapp.com).

---

**For Claude Code Users:** This project includes a `.claudecontext` file with project context and key architectural decisions. Claude Code will automatically reference this when helping with implementation.