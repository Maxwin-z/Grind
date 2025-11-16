# Repository Guidelines

## Project Structure & Module Organization
Source lives in `Grind/`, with models under `Grind/Models/`, monitoring services under `Grind/Services/Monitoring/`, database logic under `Grind/Database/Repositories/`, and UI placeholders in `Grind/Views/` plus `ViewModels/`. Helper utilities (`Utilities/Constants.swift`, `Extensions.swift`, `PermissionManager.swift`) centralize shared logic, while `Resources/` and `Assets.xcassets/` keep visual assets isolated. `GrindApp.swift` boots the singletons (ActivityMonitor, DatabaseManager) before showing any SwiftUI scenes; keep new modules aligned with this layering so heartbeats flow Models → Services → Database → Views.

## Build, Test, and Development Commands
- `open Grind.xcodeproj` loads the project in Xcode for day-to-day development and package management.
- `xcodebuild -project Grind.xcodeproj -scheme Grind -configuration Debug build` performs a full CLI build; use `Release` for profiling.
- `xcodebuild -project Grind.xcodeproj -scheme Grind test` (after UI targets exist) runs the XCTest bundle; add `-destination 'platform=macOS'` when automation requires an explicit destination.
- `xcodebuild -project Grind.xcodeproj -scheme Grind clean` clears DerivedData artifacts when linker issues appear.

## Coding Style & Naming Conventions
Follow Swift API Design Guidelines: four-space indentation, braces on the same line, and `UpperCamelCase` for types while properties, functions, and enum cases remain `lowerCamelCase`. Each monitoring singleton stays in its own file and exposes a shared instance; prefer protocol extensions for shared behavior across services. Organize folders to mirror namespaces (e.g., new aggregation code belongs in `Services/Aggregation/`) and keep file names aligned with the primary type they contain. Run SwiftFormat or Xcode's reformat before committing if you touch large sections, and keep imports sorted (`Foundation`/`SwiftUI` first, third-party next).

## Testing Guidelines
Unit tests should cover heartbeat generation edge cases, idle detection thresholds, repository CRUD, and any math-heavy aggregation logic. Place new tests under `GrindTests/` once that target is created, naming methods `testScenarioExpectation()` so failures read clearly. Use stubbed GRDB connections or in-memory stores to avoid touching the real `~/Library/Application Support/Grind/grind.db`. Run the Debug build once before `xcodebuild … test` to ensure schemes are shared, and gate pull requests on green CLI test output plus a brief manual verification of ActivityMonitor logs.

## Commit & Pull Request Guidelines
Git history favors short, imperative messages (`add events`, `list all the apps`), so keep titles under ~60 characters and focused on what changes, not how. Every pull request should summarize scope, link the related PRD item if applicable, list testing commands executed, and include screenshots or log snippets for UI/monitoring changes. Tag risky areas (database migrations, permission handling) for double review, and call out any new dependencies or Info.plist additions explicitly.

## Security & Permissions Notes
This app depends on macOS Accessibility and Screen Recording permissions; never downgrade the prompts or store raw keystrokes—only aggregated counts as seen in `KeystrokeCounter`. When modifying services that interact with system events, validate behavior with temporary logging but remove verbose output before merging to keep sensitive data out of git.
