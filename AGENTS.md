# Repository Guidelines

## Project Structure & Module Organization
The workspace contains two Xcode projects, `Grind-macOS/Grind.xcodeproj` for the desktop tracker and `Grind-iOS/Grind.xcodeproj` for the companion mobile app. Each target keeps SwiftUI source under its `Grind/` directory, with feature folders such as `Models`, `ViewModels`, `Views`, `Services`, and `Utilities`. macOS-specific resources (SQLite schema, onboarding assets) live in `Grind-macOS/Grind/Database` and `Grind-macOS/Grind/Resources`. Shared design tokens sit in each platform’s `Assets.xcassets`, while scripts and docs stay under `Grind-macOS/`.

## Build, Test, and Development Commands
- `xed Grind-macOS/Grind.xcodeproj` — open the macOS workspace in Xcode with the correct schemes preloaded.
- `xcodebuild -project Grind-macOS/Grind.xcodeproj -scheme Grind -configuration Debug` — build the mac dashboard locally.
- `xcodebuild test -project Grind-macOS/Grind.xcodeproj -scheme Grind -destination 'platform=macOS,arch=arm64'` — run mac unit/UI suites; add `-enableCodeCoverage YES` when verifying coverage.
- `xcodebuild -project Grind-iOS/Grind.xcodeproj -scheme Grind -destination 'platform=iOS Simulator,name=iPhone 15'` — sanity-check iOS builds share the same models/services.

## Coding Style & Naming Conventions
Use Swift 5.9, SwiftUI, and AppKit selectively for mac features. Stick to four-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for properties/functions, and `SCREAMING_SNAKE_CASE` only for entitlement constants. Keep files scoped to a single feature; place cross-cutting helpers under `Utilities` and prefer protocol-first abstractions in `Services`. Format code with Xcode’s “Re-Indent” shortcut or `swift-format`, and run `Product ▸ Build` to surface compiler linting.

## Testing Guidelines
Create separate `GrindTests` targets per platform; keep specs alongside the app inside `Grind-*/GrindTests`. Favor XCTest with descriptive method names (`testActivityWindowStaysOnTop`). Mock network and database layers using lightweight stubs under `Tests/Support`. Maintain ≥80% coverage, and ensure analytics or monitoring modules include regression tests that assert sampling, persistence, and UI binding.

## Commit & Pull Request Guidelines
Follow the short, imperative style already in history (`Add mac idle monitor`, `Fix iOS sync crash`). Prefix the subject with the touched platform when relevant (`macOS:`, `iOS:`). Limit the body to rationale plus testing evidence (`Test: xcodebuild test`). Pull requests should include: linked issue or PRD section, screenshots/gifs for UI adjustments, simulator or hardware info for sensor changes, and explicit callouts for new entitlements or Python dependencies.

## Security & Configuration Tips
Never check in user data captured by the tracker or SQLite artifacts; add new paths to `.gitignore` if tooling generates them. When editing `Grind.entitlements` or network services, describe the capability change in the PR. Local scripts rely on iTerm2’s Python API—store tokens via Keychain rather than repo files.
