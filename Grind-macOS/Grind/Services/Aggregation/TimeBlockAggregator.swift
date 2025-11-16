//
//  TimeBlockAggregator.swift
//  Grind
//
//  Aggregates heartbeats into 5-minute time blocks
//  Implements PRD FR-009 time block aggregation
//

import Foundation

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
            projectName: heartbeat.projectName
        )

        // Accumulate duration (max 2 seconds per heartbeat)
        block.activeDuration += min(2, Int(2))

        // Add typing duration if user is typing
        if heartbeat.isTyping {
            block.typingDuration += min(2, Int(2))
        }

        // Add keystrokes
        block.keystrokeCount += heartbeat.keystrokeCount

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
            do {
                for block in blocksToSave {
                    try self?.timeBlockRepo.save(block)
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

    /// Aggregate time blocks into daily stats
    /// Should run at end of day or on-demand
    func aggregateToDailyStats(for date: Date) {
        DispatchQueue.global(qos: .background).async {
            // This would aggregate time blocks into daily_stats table
            // Implementation depends on specific requirements
            print("📊 Aggregating daily stats for \(date)")
        }
    }
}
