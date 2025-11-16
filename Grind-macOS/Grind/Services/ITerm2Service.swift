//
//  ITerm2Service.swift
//  Grind
//
//  Created by Maxwin on 2025/11/16.
//

import Foundation
import Combine
import os.log

class ITerm2Service: ObservableObject {
    static let shared = ITerm2Service()

    @Published var currentInfo: ITerm2Info?
    @Published var isLoading = false
    @Published var lastError: String?

    private let logger = Logger(subsystem: "me.maxwin.Grind", category: "ITerm2Service")
    private let eventMonitorScriptPath: String
    private var monitorProcess: Process?
    private var outputBuffer = ""
    private var isMonitoring = false

    private init() {
        // Get the path to the event monitor Python script
        // First try to find it relative to the app bundle
        if let resourcePath = Bundle.main.resourcePath {
            eventMonitorScriptPath = "\(resourcePath)/iterm2_event_monitor.py"
        } else {
            // Fallback to project directory (for development)
            eventMonitorScriptPath = "/Users/maxwin/workspace/Grind-macOS/iterm2_event_monitor.py"
        }
    }

    deinit {
        stopMonitoring()
    }

    /// Start the event-driven monitor for iTerm2
    func startMonitoring() {
        guard !isMonitoring else {
            logger.info("Event monitor already running")
            return
        }

        logger.info("Starting iTerm2 event monitor at: \(self.eventMonitorScriptPath)")

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [eventMonitorScriptPath]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Set up output handler
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let data = handle.availableData
            if data.isEmpty { return }

            if let output = String(data: data, encoding: .utf8) {
                self.handleMonitorOutput(output)
            }
        }

        // Set up error handler
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let data = handle.availableData
            if data.isEmpty { return }

            if let error = String(data: data, encoding: .utf8) {
                self.logger.debug("Monitor stderr: \(error.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }

        do {
            try process.run()
            self.monitorProcess = process
            self.isMonitoring = true

            Task { @MainActor in
                self.isLoading = true
                self.lastError = nil
            }

            logger.info("iTerm2 event monitor started successfully")
        } catch {
            logger.error("Failed to start event monitor: \(error.localizedDescription)")
            Task { @MainActor in
                self.lastError = "Failed to start monitor: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    /// Stop the event monitor
    func stopMonitoring() {
        guard isMonitoring else { return }

        logger.info("Stopping iTerm2 event monitor")

        monitorProcess?.terminate()
        monitorProcess?.waitUntilExit()
        monitorProcess = nil
        isMonitoring = false
        outputBuffer = ""

        Task { @MainActor in
            self.currentInfo = nil
            self.isLoading = false
        }
    }

    private func handleMonitorOutput(_ output: String) {
        // Append to buffer
        outputBuffer += output

        // Check for complete JSON message (delimited by ---END---)
        if let endRange = outputBuffer.range(of: "---END---") {
            let jsonString = String(outputBuffer[..<endRange.lowerBound])
            outputBuffer = String(outputBuffer[endRange.upperBound...])

            // Parse the JSON
            parseMonitorOutput(jsonString.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func parseMonitorOutput(_ jsonString: String) {
        guard !jsonString.isEmpty else { return }

        do {
            guard let data = jsonString.data(using: .utf8) else {
                throw ITerm2Error.invalidOutput
            }

            let decoder = JSONDecoder()
            let info = try decoder.decode(ITerm2Info.self, from: data)

            Task { @MainActor in
                self.currentInfo = info
                self.isLoading = false
                self.lastError = nil

                // Broadcast to network clients
                self.broadcastSessionsToNetwork(info: info)
            }

            logger.info("Updated iTerm2 info: \(info.windows.count) windows, \(info.allSessions.count) sessions")
        } catch {
            logger.error("Failed to parse monitor output: \(error.localizedDescription)")
            logger.debug("JSON that failed to parse: \(jsonString.prefix(500))")
            Task { @MainActor in
                self.lastError = "Parse error: \(error.localizedDescription)"
            }
        }
    }

    /// Called when the active app changes
    func handleAppChange(bundleId: String) {
        let isITerm = bundleId.lowercased().contains("iterm")

        if isITerm && !isMonitoring {
            // iTerm2 became active, start monitoring
            startMonitoring()
        } else if !isITerm && isMonitoring {
            // Switched away from iTerm2, stop monitoring to save resources
            stopMonitoring()
        }
    }

    /// Broadcast iTerm2 sessions to network clients
    private func broadcastSessionsToNetwork(info: ITerm2Info) {
        var windowIndex = 0
        var sessions: [ITerm2SessionData] = []

        for window in info.windows {
            var tabIndex = 0
            for tab in window.tabs {
                var paneIndex = 0
                for session in tab.sessions {
                    let sessionData = ITerm2SessionData(
                        sessionId: session.sessionId,
                        name: session.displayName,
                        currentDirectory: session.path,
                        currentCommand: session.job,
                        isActive: session.isActive,
                        windowIndex: windowIndex,
                        tabIndex: tabIndex,
                        paneIndex: paneIndex
                    )
                    sessions.append(sessionData)
                    paneIndex += 1
                }
                tabIndex += 1
            }
            windowIndex += 1
        }

        NetworkService.shared.broadcastITerm2Sessions(sessions)
    }
}

enum ITerm2Error: LocalizedError {
    case scriptExecutionFailed(String)
    case invalidOutput
    case scriptNotFound

    var errorDescription: String? {
        switch self {
        case .scriptExecutionFailed(let message):
            return "iTerm2 script failed: \(message)"
        case .invalidOutput:
            return "Invalid output from iTerm2 script"
        case .scriptNotFound:
            return "iTerm2 Python script not found"
        }
    }
}
