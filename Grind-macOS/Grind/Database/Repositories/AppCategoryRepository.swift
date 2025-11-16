//
//  AppCategoryRepository.swift
//  Grind
//
//  Repository for app category management
//  Handles app categorization lookups and updates
//

import Foundation
import GRDB

/// Repository for managing application categories
class AppCategoryRepository {
    private let dbManager = DatabaseManager.shared

    // MARK: - Create/Update

    /// Save or update an app category
    func save(_ category: AppCategory) throws {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        try db.write { db in
            try category.save(db)
        }
    }

    // MARK: - Read

    /// Get category for a bundle ID
    /// Returns default if not found
    func getCategory(forBundleId bundleId: String) throws -> AppCategory {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        if let category = try db.read({ db in
            try AppCategory
                .filter(AppCategory.Columns.bundleId == bundleId)
                .fetchOne(db)
        }) {
            return category
        }

        // Not found, create and save default
        let defaultCategory = AppCategory.createDefault(bundleId: bundleId)
        try save(defaultCategory)
        return defaultCategory
    }

    /// Get all app categories
    func getAllCategories() throws -> [AppCategory] {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        return try db.read { db in
            try AppCategory
                .order(AppCategory.Columns.appName.asc)
                .fetchAll(db)
        }
    }

    /// Get categories by type
    func getCategories(byType category: String) throws -> [AppCategory] {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        return try db.read { db in
            try AppCategory
                .filter(AppCategory.Columns.category == category)
                .order(AppCategory.Columns.appName.asc)
                .fetchAll(db)
        }
    }

    /// Get all code editors
    func getCodeEditors() throws -> [AppCategory] {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        return try db.read { db in
            try AppCategory
                .filter(AppCategory.Columns.isCodeEditor == true)
                .fetchAll(db)
        }
    }

    /// Get all terminals
    func getTerminals() throws -> [AppCategory] {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        return try db.read { db in
            try AppCategory
                .filter(AppCategory.Columns.isTerminal == true)
                .fetchAll(db)
        }
    }

    // MARK: - Update

    /// Update category for an app (user override)
    func updateCategory(bundleId: String, category: String) throws {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        try db.write { db in
            var appCategory = try AppCategory
                .filter(AppCategory.Columns.bundleId == bundleId)
                .fetchOne(db) ?? AppCategory.createDefault(bundleId: bundleId)

            appCategory.category = category
            appCategory.userOverride = true
            try appCategory.save(db)
        }
    }

    // MARK: - Delete

    /// Reset to default category (remove user override)
    func resetToDefault(bundleId: String) throws {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        try db.write { db in
            // Delete existing
            try AppCategory
                .filter(AppCategory.Columns.bundleId == bundleId)
                .deleteAll(db)

            // Insert default
            let defaultCategory = AppCategory.createDefault(bundleId: bundleId)
            try defaultCategory.insert(db)
        }
    }
}
