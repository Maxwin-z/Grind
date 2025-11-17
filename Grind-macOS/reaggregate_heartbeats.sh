#!/bin/bash
# Re-aggregate existing heartbeats into time blocks

DB_PATH="$HOME/Library/Application Support/Grind/grind.db"

echo "Re-aggregating heartbeats..."

# SQL to aggregate heartbeats into 5-minute blocks
sqlite3 "$DB_PATH" << 'SQL'
-- Clear existing data
DELETE FROM daily_stats;
DELETE FROM blocks_5min;

-- Aggregate heartbeats into time blocks
INSERT INTO blocks_5min (blockStart, appName, category, activeDuration, typingDuration, keystrokeCount, mouseMovementCount, mouseClickCount, projectName)
SELECT 
    datetime((strftime('%s', timestamp) / 300) * 300, 'unixepoch') as blockStart,
    appName,
    category,
    COUNT(*) * 2 as activeDuration,
    SUM(CASE WHEN isTyping THEN 2 ELSE 0 END) as typingDuration,
    SUM(keystrokeCount) as keystrokeCount,
    SUM(mouseMovementCount) as mouseMovementCount,
    SUM(mouseClickCount) as mouseClickCount,
    MAX(projectName) as projectName
FROM heartbeats
WHERE idleSeconds < 120
GROUP BY blockStart, appName, category;

SELECT 'Time blocks created: ' || COUNT(*) FROM blocks_5min;

-- Aggregate time blocks into daily stats
INSERT INTO daily_stats (date, appName, category, totalDuration, typingDuration, keystrokeCount, mouseMovementCount, mouseClickCount, sessionsCount, firstActive, lastActive)
SELECT 
    DATE(blockStart) as date,
    appName,
    category,
    SUM(activeDuration) as totalDuration,
    SUM(typingDuration) as typingDuration,
    SUM(keystrokeCount) as keystrokeCount,
    SUM(mouseMovementCount) as mouseMovementCount,
    SUM(mouseClickCount) as mouseClickCount,
    1 as sessionsCount,
    MIN(blockStart) as firstActive,
    MAX(blockStart) as lastActive
FROM blocks_5min
GROUP BY date, appName, category;

SELECT 'Daily stats created: ' || COUNT(*) FROM daily_stats;
SQL

echo "Done!"
