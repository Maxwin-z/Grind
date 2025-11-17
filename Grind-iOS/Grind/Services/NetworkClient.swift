//
//  NetworkClient.swift
//  Grind
//
//  Network client for connecting to Grind macOS server
//  Supports Bonjour service discovery
//

import Foundation
import Network
import Combine

class NetworkClient: NSObject, ObservableObject {
    static let shared = NetworkClient()

    // MARK: - Published Properties

    @Published var isConnected = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var historicalStats: HistoricalStatsData?
    @Published var realtimeActivity: RealtimeActivityData?
    @Published var currentKPM: Int = 0  // Keys per minute

    // MARK: - Private Properties

    private var connection: NWConnection?
    private var serviceBrowser: NWBrowser?
    private let queue = DispatchQueue(label: "com.grind.networkclient", qos: .userInitiated)
    private var messageSubject = PassthroughSubject<NetworkMessage, Never>()

    // Network configuration
    private let serverPort: UInt16 = 9527
    private let serviceType = "_grind._tcp"

    private override init() {
        super.init()
    }

    // MARK: - Service Discovery

    /// Start discovering Grind servers on local network using Bonjour
    func startServiceDiscovery() {
        connectionStatus = "Discovering servers..."

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)

        browser.stateUpdateHandler = { [weak self] newState in
            DispatchQueue.main.async {
                switch newState {
                case .ready:
                    self?.connectionStatus = "Searching for Grind servers..."
                case .failed(let error):
                    self?.connectionStatus = "Discovery failed: \(error.localizedDescription)"
                case .cancelled:
                    self?.connectionStatus = "Discovery cancelled"
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            guard let self = self else { return }

            // Connect to first available server
            if let firstResult = results.first {
                DispatchQueue.main.async {
                    self.connectionStatus = "Found server, connecting..."
                }
                self.connectToService(firstResult.endpoint)
                self.serviceBrowser?.cancel()
                self.serviceBrowser = nil
            }
        }

        browser.start(queue: queue)
        serviceBrowser = browser
    }

    /// Connect to discovered service endpoint
    private func connectToService(_ endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        startConnection(connection)
    }

    /// Manually connect to server by IP address
    func connectToServer(host: String, port: UInt16 = 9527) {
        let host = NWEndpoint.Host(host)
        let port = NWEndpoint.Port(rawValue: port)!
        let endpoint = NWEndpoint.hostPort(host: host, port: port)

        let connection = NWConnection(to: endpoint, using: .tcp)
        startConnection(connection)
    }

    // MARK: - Connection Management

    private func startConnection(_ newConnection: NWConnection) {
        // Cancel existing connection
        connection?.cancel()

        connection = newConnection

        connection?.stateUpdateHandler = { [weak self] newState in
            DispatchQueue.main.async {
                switch newState {
                case .ready:
                    self?.isConnected = true
                    self?.connectionStatus = "Connected"
                    self?.receiveMessages()
                case .preparing:
                    self?.connectionStatus = "Connecting..."
                case .waiting(let error):
                    self?.connectionStatus = "Waiting: \(error.localizedDescription)"
                case .failed(let error):
                    self?.isConnected = false
                    self?.connectionStatus = "Failed: \(error.localizedDescription)"
                case .cancelled:
                    self?.isConnected = false
                    self?.connectionStatus = "Disconnected"
                default:
                    break
                }
            }
        }

        connection?.start(queue: queue)
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        serviceBrowser?.cancel()
        serviceBrowser = nil
    }

    // MARK: - Message Receiving

    private func receiveMessages() {
        // First receive 4-byte length header
        connection?.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, !isComplete else {
                if let error = error {
                    print("❌ Error receiving length header: \(error)")
                }
                return
            }

            // Parse length (big-endian UInt32)
            let length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            // Receive message payload
            self.connection?.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { data, _, isComplete, error in
                guard let data = data, !isComplete else {
                    if let error = error {
                        print("❌ Error receiving message: \(error)")
                    }
                    return
                }

                self.parseMessage(data)

                // Continue receiving next message
                self.receiveMessages()
            }
        }
    }

    // MARK: - Message Parsing

    private func parseMessage(_ data: Data) {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let message = try decoder.decode(NetworkMessage.self, from: data)

            DispatchQueue.main.async { [weak self] in
                self?.handleMessage(message)
            }
        } catch {
            print("❌ Error parsing message: \(error)")
        }
    }

    private func handleMessage(_ message: NetworkMessage) {
        switch message.payload {
        case .welcome(let data):
            print("✅ Connected to server: \(data.deviceName) (v\(data.serverVersion))")
            connectionStatus = "Connected to \(data.deviceName)"

        case .historicalStats(let data):
            print("📊 Received historical stats: \(data.dailyStats.count) days, \(data.topApps.count) apps")
            historicalStats = data

        case .realtimeActivity(let data):
            realtimeActivity = data

        case .heartbeat(let data):
            // Calculate KPM from last minute's keystrokes
            currentKPM = data.totalKeystrokesLastMinute

        case .keystroke(let data):
            print("⌨️ Keystroke in \(data.appName)")

        case .mouseEvent(let data):
            print("🖱️ Mouse \(data.eventType) in \(data.appName)")

        case .iterm2Sessions(let data):
            print("💻 iTerm2 sessions: \(data.sessions.count)")

        case .error(let data):
            print("❌ Server error: \(data.message)")
            connectionStatus = "Error: \(data.message)"
        }

        // Publish message for subscribers
        messageSubject.send(message)
    }

    // MARK: - Message Subscription

    func messagePublisher() -> AnyPublisher<NetworkMessage, Never> {
        return messageSubject.eraseToAnyPublisher()
    }
}
