# Swift Package Dependencies

This file lists the required Swift Package Manager dependencies for the Grind project.

## Required Packages

### 1. GRDB.swift (Database)
- **URL:** `https://github.com/groue/GRDB.swift`
- **Version:** 6.0.0 or later
- **Purpose:** SQLite database management with type-safe queries and migrations
- **Documentation:** https://github.com/groue/GRDB.swift

### 2. swift-log (Logging)
- **URL:** `https://github.com/apple/swift-log`
- **Version:** 1.5.0 or later
- **Purpose:** Structured logging framework
- **Documentation:** https://github.com/apple/swift-log

## How to Add Dependencies in Xcode

1. Open `Grind.xcodeproj` in Xcode
2. Select the project in the navigator
3. Select the "Grind" target
4. Go to the "Package Dependencies" tab
5. Click the "+" button to add a package

### Adding GRDB.swift:
1. Enter: `https://github.com/groue/GRDB.swift`
2. Select "Up to Next Major Version" with minimum 6.0.0
3. Click "Add Package"
4. Select the "GRDB" product
5. Click "Add Package"

### Adding swift-log:
1. Enter: `https://github.com/apple/swift-log`
2. Select "Up to Next Major Version" with minimum 1.5.0
3. Click "Add Package"
4. Select the "Logging" product
5. Click "Add Package"

## Alternative: Command Line (if using Swift Package Manager directly)

If you convert the project to use SPM, add this to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
    .package(url: "https://github.com/apple/swift-log", from: "1.5.0"),
],
targets: [
    .target(
        name: "Grind",
        dependencies: [
            .product(name: "GRDB", package: "GRDB.swift"),
            .product(name: "Logging", package: "swift-log"),
        ]
    ),
]
```

## Verification

After adding dependencies, build the project to verify:
```bash
xcodebuild -project Grind.xcodeproj -scheme Grind -configuration Debug build
```

All models and database files should compile without errors once GRDB is added.
