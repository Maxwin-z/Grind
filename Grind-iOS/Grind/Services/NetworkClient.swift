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
    @Published var timeBlocks: TimeBlocksData?
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
        print("🔍 Starting Bonjour service discovery for '\(serviceType)'...")
        connectionStatus = "Discovering servers..."

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)

        browser.stateUpdateHandler = { [weak self] newState in
            DispatchQueue.main.async {
                print("🔄 Browser state changed: \(newState)")
                switch newState {
                case .ready:
                    print("✅ Browser ready, searching for servers...")
                    self?.connectionStatus = "Searching for Grind servers..."
                case .failed(let error):
                    print("❌ Browser failed: \(error.localizedDescription)")
                    self?.connectionStatus = "Discovery failed: \(error.localizedDescription)"
                case .cancelled:
                    print("⚠️ Browser cancelled")
                    self?.connectionStatus = "Discovery cancelled"
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            guard let self = self else { return }

            print("📡 Browse results changed:")
            print("   Found \(results.count) services")
            for result in results {
                print("   - \(result.endpoint)")
            }

            // Connect to first available server
            if let firstResult = results.first {
                print("🎯 Connecting to first server: \(firstResult.endpoint)")
                DispatchQueue.main.async {
                    self.connectionStatus = "Found server, connecting..."
                }
                self.connectToService(firstResult.endpoint)
                self.serviceBrowser?.cancel()
                self.serviceBrowser = nil
            } else {
                print("⚠️ No servers found yet")
            }
        }

        browser.start(queue: queue)
        serviceBrowser = browser
        print("✅ Browser started")
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
        print("🔌 Starting new connection...")
        // Cancel existing connection
        connection?.cancel()

        connection = newConnection

        connection?.stateUpdateHandler = { [weak self] newState in
            DispatchQueue.main.async {
                print("🔄 Connection state changed: \(newState)")
                switch newState {
                case .ready:
                    print("✅ Connection ready! Starting to receive messages...")
                    self?.isConnected = true
                    self?.connectionStatus = "Connected"
                    self?.receiveMessages()
                case .preparing:
                    print("🔄 Connection preparing...")
                    self?.connectionStatus = "Connecting..."
                case .waiting(let error):
                    print("⏳ Connection waiting: \(error.localizedDescription)")
                    self?.connectionStatus = "Waiting: \(error.localizedDescription)"
                case .failed(let error):
                    print("❌ Connection failed: \(error.localizedDescription)")
                    self?.isConnected = false
                    self?.connectionStatus = "Failed: \(error.localizedDescription)"
                case .cancelled:
                    print("⚠️ Connection cancelled")
                    self?.isConnected = false
                    self?.connectionStatus = "Disconnected"
                default:
                    break
                }
            }
        }

        connection?.start(queue: queue)
        print("✅ Connection start initiated")
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        serviceBrowser?.cancel()
        serviceBrowser = nil
    }

    // MARK: - Message Receiving

    private func receiveMessages() {
        print("📥 Starting to receive messages...")
        // First receive 4-byte length header
        connection?.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, !isComplete else {
                if let error = error {
                    print("❌ Error receiving length header: \(error)")
                } else if isComplete {
                    print("⚠️ Connection closed while receiving length header")
                }
                return
            }

            // Parse length (big-endian UInt32)
            let length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            print("📨 Received length header: \(length) bytes")

            // Receive message payload
            self.connection?.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { data, _, isComplete, error in
                guard let data = data, !isComplete else {
                    if let error = error {
                        print("❌ Error receiving message: \(error)")
                    } else if isComplete {
                        print("⚠️ Connection closed while receiving message payload")
                    }
                    return
                }

                print("📦 Received message payload: \(data.count) bytes")
                self.parseMessage(data)

                // Continue receiving next message
                self.receiveMessages()
            }
        }
    }

    // MARK: - Message Parsing

    private func parseMessage(_ data: Data) {
        print("🔍 Parsing message...")

        // First, try to peek at the message type
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📄 Raw JSON (first 200 chars): \(String(jsonString.prefix(200)))")
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let message = try decoder.decode(NetworkMessage.self, from: data)
            print("✅ Successfully parsed message type: \(message.type)")

            DispatchQueue.main.async { [weak self] in
                self?.handleMessage(message)
            }
        } catch {
            print("❌ Error parsing message: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   Missing key: \(key.stringValue), context: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("   Type mismatch: \(type), context: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("   Value not found: \(type), context: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("   Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("   Unknown decoding error")
                }
            }
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

        case .timeBlocks(let data):
            print("📅 Received time blocks for \(data.date): \(data.blocks.count) blocks")
            timeBlocks = data

        case .realtimeActivity(let data):
            realtimeActivity = data

        case .heartbeat(let data):
            // Calculate KPM from last minute's keystrokes
            currentKPM = data.keystrokesLastMinute

        case .keystroke(let data):
            print("⌨️ Keystroke: \(data.key) in \(data.appBundleIdentifier)")

        case .mouseEvent(let data):
            print("🖱️ Mouse \(data.eventType) in \(data.appBundleIdentifier)")

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
