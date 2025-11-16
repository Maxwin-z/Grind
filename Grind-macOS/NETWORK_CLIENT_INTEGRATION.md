# Grind Network Service - iOS Client Integration Guide

This document describes how to connect to the Grind macOS activity monitoring server from an iOS client application.

## Overview

The Grind macOS app runs a TCP server on port **9527** that broadcasts real-time activity monitoring data to connected clients. The server uses a JSON-based message protocol with length-prefixed framing.

## Connection Details

- **Protocol**: TCP
- **Port**: 9527
- **Service Discovery**: Bonjour service `_grind._tcp`
- **Network**: Local network only (server accepts local connections only)
- **Message Format**: JSON with 4-byte length prefix

## Message Protocol

### Frame Format

Each message is framed with a 4-byte length prefix (UInt32, little-endian) followed by JSON data:

```
[4 bytes: message length] [JSON payload]
```

### Message Types

All messages follow this base structure:

```json
{
  "type": "message_type",
  "timestamp": "2025-11-16T12:34:56.789Z",
  ...additional fields...
}
```

Message types:
- `welcome` - Initial connection welcome
- `historicalStats` - Historical activity statistics
- `realtimeActivity` - Real-time activity update (every 2 seconds)
- `keystroke` - Individual keystroke event
- `mouseEvent` - Mouse click/movement event
- `iterm2Sessions` - iTerm2 terminal sessions info
- `heartbeat` - Periodic heartbeat with activity summary
- `error` - Error message

## Connection Flow

### 1. Connect to Server

#### Using Bonjour Discovery (Recommended)

```swift
import Network

class GrindClient {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.yourapp.grind")

    func discoverAndConnect() {
        let browser = NWBrowser(for: .bonjour(type: "_grind._tcp", domain: nil), using: .tcp)

        browser.browseResultsChangedHandler = { results, changes in
            for result in results {
                if case .service(let name, let type, let domain, let interface) = result.endpoint {
                    print("Found Grind server: \(name)")
                    self.connect(to: result.endpoint)
                    browser.cancel()
                    break
                }
            }
        }

        browser.start(queue: queue)
    }

    private func connect(to endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        self.connection = connection

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Connected to Grind server")
                self.startReceiving()
            case .failed(let error):
                print("Connection failed: \(error)")
            case .cancelled:
                print("Connection cancelled")
            default:
                break
            }
        }

        connection.start(queue: queue)
    }
}
```

#### Direct Connection

```swift
func connectDirect(host: String = "localhost", port: UInt16 = 9527) {
    let endpoint = NWEndpoint.hostPort(
        host: NWEndpoint.Host(host),
        port: NWEndpoint.Port(rawValue: port)!
    )

    let connection = NWConnection(to: endpoint, using: .tcp)
    self.connection = connection

    connection.stateUpdateHandler = { state in
        // Handle state changes
    }

    connection.start(queue: queue)
}
```

### 2. Receive Messages

```swift
private var receiveBuffer = Data()

func startReceiving() {
    receiveMessage()
}

private func receiveMessage() {
    // First, receive the 4-byte length prefix
    connection?.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, isComplete, error in
        guard let self = self, let data = data, data.count == 4 else {
            if let error = error {
                print("Receive error: \(error)")
            }
            return
        }

        // Parse length (UInt32 little-endian)
        let length = data.withUnsafeBytes { $0.load(as: UInt32.self) }

        // Now receive the JSON payload
        self.connection?.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { data, _, isComplete, error in
            guard let jsonData = data else { return }

            do {
                let message = try JSONDecoder().decode(GrindMessage.self, from: jsonData)
                self.handleMessage(message)
            } catch {
                print("Failed to decode message: \(error)")
            }

            // Continue receiving next message
            self.receiveMessage()
        }
    }
}
```

### 3. Handle Messages

Define Swift models matching the message types:

```swift
// Base message protocol
protocol GrindMessage: Codable {
    var type: MessageType { get }
    var timestamp: Date { get }
}

enum MessageType: String, Codable {
    case welcome
    case historicalStats
    case realtimeActivity
    case keystroke
    case mouseEvent
    case iterm2Sessions
    case heartbeat
    case error
}

// Decode messages
func handleMessage(_ messageData: Data) throws {
    // First, peek at the type
    struct TypeWrapper: Codable {
        let type: MessageType
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let wrapper = try decoder.decode(TypeWrapper.self, from: messageData)

    // Then decode the full message based on type
    switch wrapper.type {
    case .welcome:
        let msg = try decoder.decode(WelcomeMessage.self, from: messageData)
        handleWelcome(msg)
    case .historicalStats:
        let msg = try decoder.decode(HistoricalStatsMessage.self, from: messageData)
        handleHistoricalStats(msg)
    case .realtimeActivity:
        let msg = try decoder.decode(RealtimeActivityMessage.self, from: messageData)
        handleRealtimeActivity(msg)
    case .keystroke:
        let msg = try decoder.decode(KeystrokeMessage.self, from: messageData)
        handleKeystroke(msg)
    case .mouseEvent:
        let msg = try decoder.decode(MouseEventMessage.self, from: messageData)
        handleMouseEvent(msg)
    case .iterm2Sessions:
        let msg = try decoder.decode(ITerm2SessionsMessage.self, from: messageData)
        handleITerm2Sessions(msg)
    case .heartbeat:
        let msg = try decoder.decode(HeartbeatMessage.self, from: messageData)
        handleHeartbeat(msg)
    case .error:
        let msg = try decoder.decode(ErrorMessage.self, from: messageData)
        handleError(msg)
    }
}
```

## Message Types Reference

### WelcomeMessage

Sent immediately upon connection.

```swift
struct WelcomeMessage: GrindMessage {
    let type: MessageType = .welcome
    let timestamp: Date
    let serverVersion: String
    let deviceName: String
}
```

Example JSON:
```json
{
  "type": "welcome",
  "timestamp": "2025-11-16T12:00:00.000Z",
  "serverVersion": "1.0.0",
  "deviceName": "Max's MacBook Pro"
}
```

### HistoricalStatsMessage

Sent once after connection, contains last 30 days of activity.

```swift
struct HistoricalStatsMessage: GrindMessage {
    let type: MessageType = .historicalStats
    let timestamp: Date
    let dailyStats: [DailyStatsData]
    let topApps: [AppStatsData]
}

struct DailyStatsData: Codable {
    let date: String // "YYYY-MM-DD"
    let totalSeconds: Int
    let totalKeystrokes: Int
    let totalMouseMovements: Int
    let totalMouseClicks: Int
    let appCount: Int
}

struct AppStatsData: Codable {
    let bundleIdentifier: String
    let appName: String
    let iconPath: String?
    let totalSeconds: Int
    let keystrokes: Int
    let mouseMovements: Int
    let mouseClicks: Int
    let lastActive: Date?
}
```

Example JSON:
```json
{
  "type": "historicalStats",
  "timestamp": "2025-11-16T12:00:00.000Z",
  "dailyStats": [
    {
      "date": "2025-11-16",
      "totalSeconds": 28800,
      "totalKeystrokes": 5420,
      "totalMouseMovements": 12340,
      "totalMouseClicks": 234,
      "appCount": 8
    }
  ],
  "topApps": [
    {
      "bundleIdentifier": "com.apple.dt.Xcode",
      "appName": "Xcode",
      "iconPath": null,
      "totalSeconds": 14400,
      "keystrokes": 3200,
      "mouseMovements": 4500,
      "mouseClicks": 120,
      "lastActive": "2025-11-16T11:30:00.000Z"
    }
  ]
}
```

### RealtimeActivityMessage

Sent every 2 seconds with current activity snapshot.

```swift
struct RealtimeActivityMessage: GrindMessage {
    let type: MessageType = .realtimeActivity
    let timestamp: Date
    let activeApp: ActiveAppData
    let isTyping: Bool
    let idleSeconds: Double
    let keystrokesSinceLastUpdate: Int
    let mouseMovementsSinceLastUpdate: Int
    let mouseClicksSinceLastUpdate: Int
}

struct ActiveAppData: Codable {
    let bundleIdentifier: String
    let appName: String
    let windowTitle: String?
    let projectName: String?
}
```

Example JSON:
```json
{
  "type": "realtimeActivity",
  "timestamp": "2025-11-16T12:00:02.000Z",
  "activeApp": {
    "bundleIdentifier": "com.apple.dt.Xcode",
    "appName": "Xcode",
    "windowTitle": "ContentView.swift",
    "projectName": "Grind"
  },
  "isTyping": true,
  "idleSeconds": 2.5,
  "keystrokesSinceLastUpdate": 12,
  "mouseMovementsSinceLastUpdate": 3,
  "mouseClicksSinceLastUpdate": 0
}
```

### KeystrokeMessage

Sent for each individual keystroke (real-time).

```swift
struct KeystrokeMessage: GrindMessage {
    let type: MessageType = .keystroke
    let timestamp: Date
    let key: String
    let keyCode: UInt16
    let modifiers: [String]
    let appBundleIdentifier: String
}
```

Example JSON:
```json
{
  "type": "keystroke",
  "timestamp": "2025-11-16T12:00:00.123Z",
  "key": "a",
  "keyCode": 0,
  "modifiers": ["Command", "Shift"],
  "appBundleIdentifier": "com.apple.dt.Xcode"
}
```

Modifier values: `"Command"`, `"Shift"`, `"Option"`, `"Control"`, `"Fn"`

### MouseEventMessage

Sent for mouse clicks and movements (throttled - movements every 10th event).

```swift
struct MouseEventMessage: GrindMessage {
    let type: MessageType = .mouseEvent
    let timestamp: Date
    let eventType: MouseEventType
    let x: Double?
    let y: Double?
    let button: Int?
    let appBundleIdentifier: String
}

enum MouseEventType: String, Codable {
    case movement
    case leftClick
    case rightClick
    case otherClick
    case scroll
}
```

Example JSON:
```json
{
  "type": "mouseEvent",
  "timestamp": "2025-11-16T12:00:00.456Z",
  "eventType": "leftClick",
  "x": 1024.5,
  "y": 768.3,
  "button": 0,
  "appBundleIdentifier": "com.google.Chrome"
}
```

### ITerm2SessionsMessage

Sent when iTerm2 session state changes.

```swift
struct ITerm2SessionsMessage: GrindMessage {
    let type: MessageType = .iterm2Sessions
    let timestamp: Date
    let sessions: [ITerm2SessionData]
}

struct ITerm2SessionData: Codable {
    let sessionId: String
    let name: String
    let currentDirectory: String?
    let currentCommand: String?
    let isActive: Bool
    let windowIndex: Int
    let tabIndex: Int
    let paneIndex: Int
}
```

Example JSON:
```json
{
  "type": "iterm2Sessions",
  "timestamp": "2025-11-16T12:00:00.789Z",
  "sessions": [
    {
      "sessionId": "w0t0p0",
      "name": "zsh",
      "currentDirectory": "/Users/max/workspace/Grind-macOS",
      "currentCommand": "vim ContentView.swift",
      "isActive": true,
      "windowIndex": 0,
      "tabIndex": 0,
      "paneIndex": 0
    }
  ]
}
```

### HeartbeatMessage

Periodic keep-alive with activity summary.

```swift
struct HeartbeatMessage: GrindMessage {
    let type: MessageType = .heartbeat
    let timestamp: Date
    let activeApp: ActiveAppData?
    let isActive: Bool
    let keystrokesLastMinute: Int
    let mouseEventsLastMinute: Int
}
```

### ErrorMessage

```swift
struct ErrorMessage: GrindMessage {
    let type: MessageType = .error
    let timestamp: Date
    let errorCode: String
    let message: String
}
```

## Complete iOS Client Example

```swift
import Foundation
import Network

class GrindActivityClient: ObservableObject {
    @Published var isConnected = false
    @Published var currentActivity: RealtimeActivityMessage?
    @Published var historicalStats: HistoricalStatsMessage?
    @Published var iTerm2Sessions: [ITerm2SessionData] = []
    @Published var recentKeystrokes: [KeystrokeMessage] = []

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.yourapp.grind")

    func connect(host: String, port: UInt16 = 9527) {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!
        )

        let connection = NWConnection(to: endpoint, using: .tcp)
        self.connection = connection

        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    print("Connected to Grind server")
                    self?.startReceiving()
                case .failed(let error):
                    self?.isConnected = false
                    print("Connection failed: \(error)")
                case .cancelled:
                    self?.isConnected = false
                default:
                    break
                }
            }
        }

        connection.start(queue: queue)
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
    }

    private func startReceiving() {
        receiveNextMessage()
    }

    private func receiveNextMessage() {
        // Read 4-byte length prefix
        connection?.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, _, error in
            guard let self = self, let data = data, data.count == 4, error == nil else {
                return
            }

            let length = data.withUnsafeBytes { $0.load(as: UInt32.self) }

            // Read JSON payload
            self.connection?.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { data, _, _, error in
                guard let jsonData = data, error == nil else { return }

                self.processMessage(jsonData)

                // Continue receiving
                self.receiveNextMessage()
            }
        }
    }

    private func processMessage(_ data: Data) {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // Peek at type
            struct TypeWrapper: Codable {
                let type: MessageType
            }
            let wrapper = try decoder.decode(TypeWrapper.self, from: data)

            DispatchQueue.main.async {
                switch wrapper.type {
                case .welcome:
                    let msg = try? decoder.decode(WelcomeMessage.self, from: data)
                    print("Welcome from: \(msg?.deviceName ?? "unknown")")

                case .historicalStats:
                    self.historicalStats = try? decoder.decode(HistoricalStatsMessage.self, from: data)

                case .realtimeActivity:
                    self.currentActivity = try? decoder.decode(RealtimeActivityMessage.self, from: data)

                case .keystroke:
                    if let msg = try? decoder.decode(KeystrokeMessage.self, from: data) {
                        self.recentKeystrokes.append(msg)
                        if self.recentKeystrokes.count > 100 {
                            self.recentKeystrokes.removeFirst()
                        }
                    }

                case .iterm2Sessions:
                    if let msg = try? decoder.decode(ITerm2SessionsMessage.self, from: data) {
                        self.iTerm2Sessions = msg.sessions
                    }

                default:
                    break
                }
            }
        } catch {
            print("Error processing message: \(error)")
        }
    }
}
```

## SwiftUI Usage Example

```swift
import SwiftUI

struct ActivityMonitorView: View {
    @StateObject private var client = GrindActivityClient()
    @State private var serverIP = "192.168.1.100"

    var body: some View {
        VStack {
            if client.isConnected {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Connected to Mac")
                        .font(.headline)

                    if let activity = client.currentActivity {
                        Text("App: \(activity.activeApp.appName)")
                        Text("Window: \(activity.activeApp.windowTitle ?? "N/A")")
                        Text("Typing: \(activity.isTyping ? "Yes" : "No")")
                        Text("Idle: \(Int(activity.idleSeconds))s")
                        Text("Keys: \(activity.keystrokesSinceLastUpdate)")
                    }

                    Button("Disconnect") {
                        client.disconnect()
                    }
                }
            } else {
                TextField("Server IP", text: $serverIP)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                Button("Connect") {
                    client.connect(host: serverIP)
                }
            }
        }
        .padding()
    }
}
```

## Security Considerations

1. **Local Network Only**: The server only accepts connections from the local network
2. **No Authentication**: Currently no authentication mechanism - ensure network security
3. **Privacy**: Keystroke data includes actual keys pressed - handle securely
4. **Encryption**: Consider adding TLS for production use

## Troubleshooting

### Cannot Connect
- Ensure Mac and iOS device are on same network
- Check firewall settings on Mac
- Verify port 9527 is not blocked
- Try using Mac's IP address instead of hostname

### Connection Drops
- Check network stability
- Implement reconnection logic with exponential backoff
- Monitor connection state changes

### Missing Messages
- Ensure proper framing (4-byte length prefix)
- Verify JSON decoding with correct date strategy
- Check for network buffering issues

## Performance Notes

- **Real-time Updates**: Sent every 2 seconds
- **Keystroke Messages**: Sent immediately for each key
- **Mouse Movements**: Throttled to every 10th movement
- **Mouse Clicks**: Sent immediately
- **iTerm2 Updates**: Sent on session state changes only

## Next Steps

1. Implement reconnection logic
2. Add data persistence on iOS
3. Create visualizations for activity data
4. Add filtering/search capabilities
5. Implement secure authentication
6. Add TLS encryption for production

## Support

For issues or questions, please refer to the Grind macOS source code:
- NetworkService.swift - Server implementation
- NetworkMessage.swift - Message protocol definitions
