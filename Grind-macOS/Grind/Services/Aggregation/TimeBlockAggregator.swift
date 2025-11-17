//
//  TimeBlockAggregator.swift
//  Grind
//
//  Aggregates heartbeats into 5-minute time blocks
//  Implements PRD FR-009 time block aggregation
//

import Foundation
import GRDB

/// Service for aggregating heartbeats into 5-minute time blocks
/// Runs in background to maintain performance
class TimeBlockAggregator {
    static let shared = TimeBlockAggregator()

    private let timeBlockRepo = TimeBlockRepository()

    // Cache current block to minimize database writes
    private var currentBlockCache: [String: TimeBlock] = [:]  // key: "blockStart_appName"
    private var lastFlushTime = Date()
    private let flushInterval: TimeInterval = 30  // Flush every 30 seconds

    private init() {
        // Schedule periodic flush
        Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            self?.flushCache()
        }
    }

    // MARK: - Aggregation

    /// Aggregate a heartbeat into a 5-minute time block
    /// Per PRD FR-009
    func aggregateHeartbeat(_ heartbeat: Heartbeat) {
        // Round to 5-minute boundary
        let blockStart = TimeBlock.roundTo5Minutes(heartbeat.timestamp)

        // Generate cache key
        let cacheKey = "\(blockStart.timeIntervalSince1970)_\(heartbeat.appName)"

        // Get or create block from cache
        var block = currentBlockCache[cacheKey] ?? TimeBlock(
            blockStart: blockStart,
            appName: heartbeat.appName,
            category: heartbeat.category,
            activeDuration: 0,
            typingDuration: 0,
            keystrokeCount: 0,
            mouseMovementCount: 0,
            mouseClickCount: 0,
            projectName: heartbeat.projectName
        )

        // Accumulate duration (max 2 seconds per heartbeat)
        block.activeDuration += min(2, Int(2))

        // Add typing duration if user is typing
        if heartbeat.isTyping {
            block.typingDuration += min(2, Int(2))
        }

        // Add keystrokes and mouse activity
        block.keystrokeCount += heartbeat.keystrokeCount
        block.mouseMovementCount += heartbeat.mouseMovementCount
        block.mouseClickCount += heartbeat.mouseClickCount

        // Update cache
        currentBlockCache[cacheKey] = block

        // Check if we should flush
        if Date().timeIntervalSince(lastFlushTime) > flushInterval {
            flushCache()
        }
    }

    /// Flush cached blocks to database
    func flushCache() {
        guard !currentBlockCache.isEmpty else { return }

        let blocksToSave = Array(currentBlockCache.values)

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            do {
                guard let db = DatabaseManager.shared.getDatabase() else {
                    print("❌ Database not initialized")
                    return
                }

                // Properly accumulate durations by merging with existing blocks
                try db.write { db in
                    for block in blocksToSave {
                        // Try to fetch existing block
                        if var existing = try TimeBlock
                            .filter(TimeBlock.Columns.blockStart == block.blockStart && TimeBlock.Columns.appName == block.appName)
                            .fetchOne(db) {
                            // Accumulate durations
                            existing.activeDuration += block.activeDuration
                            existing.typingDuration += block.typingDuration
                            existing.keystrokeCount += block.keystrokeCount
                            existing.mouseMovementCount += block.mouseMovementCount
                            existing.mouseClickCount += block.mouseClickCount
                            try existing.update(db)
                        } else {
                            // Create new block
                            try block.insert(db)
                        }
                    }
                }
                print("💾 Flushed \(blocksToSave.count) time blocks to database")
            } catch {
                print("❌ Error flushing time blocks: \(error)")
            }
        }

        // Clear cache
        currentBlockCache.removeAll()
        lastFlushTime = Date()
    }

    // MARK: - Daily Aggregation

    /// Aggregate time blocks into daily stats asynchronously
    /// Should run at end of day or on-demand
    func aggregateToDailyStats(for date: Date) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            do {
                try self.performDailyAggregation(for: date)
                print("✅ Daily stats aggregated for \(DailyStats.dateString(from: date))")
            } catch {
                print("❌ Error aggregating daily stats: \(error)")
            }
        }
    }

    /// Aggregate time blocks into daily stats synchronously
    func aggregateToDailyStatsSync(for date: Date) throws {
        try performDailyAggregation(for: date)
        print("✅ Daily stats aggregated for \(DailyStats.dateString(from: date))")
    }

    /// Ensure a given date has daily stats rows by aggregating if needed
    func ensureDailyStats(for date: Date) throws {
        let dateString = DailyStats.dateString(from: date)
        let calendar = Calendar.current

        // Always re-aggregate for current day to reflect the latest data
        if calendar.isDate(date, inSameDayAs: Date()) {
            try aggregateToDailyStatsSync(for: date)
            return
        }

        let existing = try DailyStatsRepository.shared.getStats(forDate: dateString)

        guard existing.isEmpty else {
            return
        }

        try aggregateToDailyStatsSync(for: date)
    }

    /// Perform the actual daily aggregation logic
    private func performDailyAggregation(for date: Date) throws {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Get all time blocks for this day
        let blocks = try timeBlockRepo.getBlocks(from: startOfDay, to: endOfDay)

        guard !blocks.isEmpty else {
            print("⚠️ No time blocks found for \(DailyStats.dateString(from: date))")
            return
        }

        // Group blocks by app name
        let groupedBlocks = Dictionary(grouping: blocks) { $0.appName }

        let dailyStatsRepo = DailyStatsRepository.shared
        let dateString = DailyStats.dateString(from: date)

        // Aggregate each app's data
        for (appName, appBlocks) in groupedBlocks {
            let category = appBlocks.first?.category ?? "Other"

            // Sum up durations and counts
            var totalDuration = 0
            var typingDuration = 0
            var keystrokeCount = 0
            var mouseMovementCount = 0
            var mouseClickCount = 0
            var firstActive: Date?
            var lastActive: Date?

            for block in appBlocks {
                totalDuration += block.activeDuration
                typingDuration += block.typingDuration
                keystrokeCount += block.keystrokeCount
                mouseMovementCount += block.mouseMovementCount
                mouseClickCount += block.mouseClickCount

                // Track first and last active timestamps
                if firstActive == nil || block.blockStart < firstActive! {
                    firstActive = block.blockStart
                }
                if lastActive == nil || block.blockStart > lastActive! {
                    lastActive = block.blockStart
                }
            }

            // Calculate session count (gaps > 120s between blocks)
            let sessionsCount = calculateSessionCount(from: appBlocks)

            // Create or update daily stats record
            let stats = DailyStats(
                date: dateString,
                appName: appName,
                category: category,
                totalDuration: totalDuration,
                typingDuration: typingDuration,
                keystrokeCount: keystrokeCount,
                mouseMovementCount: mouseMovementCount,
                mouseClickCount: mouseClickCount,
                sessionsCount: sessionsCount,
                firstActive: firstActive,
                lastActive: lastActive
            )

            try dailyStatsRepo.save(stats)
        }

        print("📊 Aggregated \(groupedBlocks.count) apps into daily stats for \(dateString)")
    }

    /// Calculate number of sessions based on time gaps between blocks
    /// A new session starts when gap > 120 seconds (2 minutes)
    private func calculateSessionCount(from blocks: [TimeBlock]) -> Int {
        guard !blocks.isEmpty else { return 0 }

        // Sort blocks by time
        let sortedBlocks = blocks.sorted { $0.blockStart < $1.blockStart }

        var sessionCount = 1
        var previousBlockEnd = sortedBlocks[0].blockStart.addingTimeInterval(300) // 5 minutes

        for i in 1..<sortedBlocks.count {
            let currentBlockStart = sortedBlocks[i].blockStart
            let gap = currentBlockStart.timeIntervalSince(previousBlockEnd)

            // If gap > 120 seconds, it's a new session
            if gap > 120 {
                sessionCount += 1
            }

            previousBlockEnd = currentBlockStart.addingTimeInterval(300)
        }

        return sessionCount
    }
}
