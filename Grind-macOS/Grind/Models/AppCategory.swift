//
//  AppCategory.swift
//  Grind
//
//  Application categorization for better insights
//  See PRD FR-010 for categorization logic
//

import Foundation
import GRDB

/// Application category mapping
/// Allows automatic categorization and user overrides
struct AppCategory: Codable {
    var bundleId: String
    var appName: String
    var category: String
    var isCodeEditor: Bool
    var isTerminal: Bool
    var userOverride: Bool      // True if user manually changed category

    init(
        bundleId: String,
        appName: String,
        category: String,
        isCodeEditor: Bool = false,
        isTerminal: Bool = false,
        userOverride: Bool = false
    ) {
        self.bundleId = bundleId
        self.appName = appName
        self.category = category
        self.isCodeEditor = isCodeEditor
        self.isTerminal = isTerminal
        self.userOverride = userOverride
    }
}

// MARK: - GRDB Support
extension AppCategory: FetchableRecord, PersistableRecord {
    static let databaseTableName = "app_categories"

    enum Columns {
        static let bundleId = Column("bundleId")
        static let appName = Column("appName")
        static let category = Column("category")
        static let isCodeEditor = Column("isCodeEditor")
        static let isTerminal = Column("isTerminal")
        static let userOverride = Column("userOverride")
    }
}

// MARK: - Category Definitions
extension AppCategory {
    /// Standard app categories from PRD FR-010
    enum Category: String, CaseIterable {
        case coding = "Coding"
        case terminal = "Terminal"
        case browsing = "Browsing"
        case communication = "Communication"
        case design = "Design"
        case documentation = "Documentation"
        case utilities = "Utilities"
        case entertainment = "Entertainment"
        case meetings = "Meetings"
        case other = "Other"

        /// Color for category visualization
        var color: String {
            switch self {
            case .coding: return "#007AFF"
            case .terminal: return "#34C759"
            case .browsing: return "#FF9500"
            case .communication: return "#AF52DE"
            case .design: return "#FF2D55"
            case .documentation: return "#5AC8FA"
            case .entertainment: return "#FF3B30"
            case .utilities: return "#8E8E93"
            case .meetings: return "#FFD60A"
            case .other: return "#98989D"
            }
        }
    }

    /// Default category mappings from PRD FR-010
    static let defaultMappings: [String: (name: String, category: String, isCodeEditor: Bool, isTerminal: Bool)] = [
        // Code Editors
        "com.apple.dt.Xcode": ("Xcode", "Coding", true, false),
        "com.microsoft.VSCode": ("Visual Studio Code", "Coding", true, false),
        "com.jetbrains.intellij": ("IntelliJ IDEA", "Coding", true, false),
        "com.sublimetext.4": ("Sublime Text", "Coding", true, false),
        "com.github.atom": ("Atom", "Coding", true, false),
        "com.panic.Nova": ("Nova", "Coding", true, false),
        "com.barebones.bbedit": ("BBEdit", "Coding", true, false),

        // Terminals
        "com.googlecode.iterm2": ("iTerm2", "Terminal", false, true),
        "com.apple.Terminal": ("Terminal", "Terminal", false, true),
        "net.kovidgoyal.kitty": ("Kitty", "Terminal", false, true),
        "co.zeit.hyper": ("Hyper", "Terminal", false, true),

        // Browsers
        "com.apple.Safari": ("Safari", "Browsing", false, false),
        "com.google.Chrome": ("Google Chrome", "Browsing", false, false),
        "org.mozilla.firefox": ("Firefox", "Browsing", false, false),
        "com.brave.Browser": ("Brave", "Browsing", false, false),
        "com.microsoft.edgemac": ("Microsoft Edge", "Browsing", false, false),

        // Communication
        "com.tinyspeck.slackmacgap": ("Slack", "Communication", false, false),
        "com.hnc.Discord": ("Discord", "Communication", false, false),
        "com.apple.mail": ("Mail", "Communication", false, false),
        "com.apple.MobileSMS": ("Messages", "Communication", false, false),
        "com.microsoft.teams2": ("Microsoft Teams", "Communication", false, false),
        "us.zoom.xos": ("Zoom", "Meetings", false, false),

        // Design
        "com.figma.Desktop": ("Figma", "Design", false, false),
        "com.bohemiancoding.sketch3": ("Sketch", "Design", false, false),
        "com.adobe.Photoshop": ("Adobe Photoshop", "Design", false, false),
        "com.adobe.illustrator": ("Adobe Illustrator", "Design", false, false),

        // Documentation
        "notion.id": ("Notion", "Documentation", false, false),
        "net.shinyfrog.bear": ("Bear", "Documentation", false, false),
        "md.obsidian": ("Obsidian", "Documentation", false, false),
        "com.apple.Notes": ("Notes", "Documentation", false, false),

        // Utilities
        "com.apple.finder": ("Finder", "Utilities", false, false),
        "com.apple.systempreferences": ("System Preferences", "Utilities", false, false),
        "com.apple.ActivityMonitor": ("Activity Monitor", "Utilities", false, false),

        // Entertainment
        "com.spotify.client": ("Spotify", "Entertainment", false, false),
        "com.apple.TV": ("Apple TV", "Entertainment", false, false),
    ]

    /// Create default app category
    static func createDefault(bundleId: String) -> AppCategory {
        if let mapping = defaultMappings[bundleId] {
            return AppCategory(
                bundleId: bundleId,
                appName: mapping.name,
                category: mapping.category,
                isCodeEditor: mapping.isCodeEditor,
                isTerminal: mapping.isTerminal,
                userOverride: false
            )
        }

        // Try to infer from bundle ID
        let inferredCategory = inferCategory(from: bundleId)
        return AppCategory(
            bundleId: bundleId,
            appName: bundleId.components(separatedBy: ".").last ?? "Unknown",
            category: inferredCategory,
            isCodeEditor: false,
            isTerminal: false,
            userOverride: false
        )
    }

    /// Infer category from bundle ID patterns
    private static func inferCategory(from bundleId: String) -> String {
        let lowercased = bundleId.lowercased()

        if lowercased.contains("editor") || lowercased.contains("code") {
            return "Coding"
        } else if lowercased.contains("terminal") || lowercased.contains("console") {
            return "Terminal"
        } else if lowercased.contains("browser") || lowercased.contains("safari") {
            return "Browsing"
        } else if lowercased.contains("mail") || lowercased.contains("message") || lowercased.contains("chat") {
            return "Communication"
        } else if lowercased.contains("design") || lowercased.contains("sketch") || lowercased.contains("figma") {
            return "Design"
        } else if lowercased.contains("note") || lowercased.contains("document") {
            return "Documentation"
        }

        return "Other"
    }
}
