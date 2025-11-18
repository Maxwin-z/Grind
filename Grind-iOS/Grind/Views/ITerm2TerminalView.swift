//
//  ITerm2TerminalView.swift
//  Grind
//
//  Terminal view that renders iTerm2 content with 1:1 color accuracy
//

import SwiftUI

// Shared terminal typography so spacing stays in sync with size tweaks
private let terminalFontSize: CGFloat = 24
private let terminalFont: Font = .system(size: terminalFontSize, design: .monospaced)
private let terminalLineHeight: CGFloat = terminalFontSize * 1.2

// MARK: - RGBColor Extension

extension RGBColor {
    /// Convert to SwiftUI Color
    var color: Color {
        Color(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}

// MARK: - Terminal Line View

struct TerminalLineView: View {
    let line: ITerm2StyledLine

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(line.characters.enumerated()), id: \.offset) { index, char in
                TerminalCharacterView(character: char)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Terminal Character View

struct TerminalCharacterView: View {
    let character: ITerm2Character

    var body: some View {
        Text(character.char.isEmpty ? " " : character.char)
            .font(terminalFont)
            .fontWeight(character.bold ? .bold : .regular)
            .italic(character.italic)
            .underline(character.underline)
            .foregroundColor(character.fgColor?.color ?? .white)
            .background(character.bgColor?.color ?? Color.clear)
    }
}

// MARK: - Main Terminal View

struct ITerm2TerminalView: View {
    let session: ITerm2Session
    @State private var scrollOffset: CGFloat = 0

    // Default terminal colors (fallback when no color specified)
    private let defaultForeground = Color.white
    private let defaultBackground = Color.black

    private var resolvedStyledLines: [ITerm2StyledLine]? {
        if let styled = session.styledLines, !styled.isEmpty {
            return removeTrailingBlankStyledLines(styled)
        }
        if let screenLines = session.screenLines, !screenLines.isEmpty {
            let trimmedLines = removeTrailingBlankLines(screenLines)
            return ANSIColorParser.styledLines(from: trimmedLines)
        }
        return nil
    }

    /// Remove trailing blank lines from styled lines array
    private func removeTrailingBlankStyledLines(_ lines: [ITerm2StyledLine]) -> [ITerm2StyledLine] {
        var result = lines
        while let last = result.last, isStyledLineBlank(last) {
            result.removeLast()
        }
        return result
    }

    /// Check if a styled line is blank (contains only whitespace or invisible characters)
    private func isStyledLineBlank(_ line: ITerm2StyledLine) -> Bool {
        // Check if all characters are whitespace or invisible
        return line.characters.allSatisfy { char in
            let trimmed = char.char.trimmingCharacters(in: .whitespacesAndNewlines)
            // Consider it blank if:
            // 1. Empty after trimming whitespace
            // 2. Contains only null characters or other control characters
            return trimmed.isEmpty || trimmed.allSatisfy { $0.isWhitespace || $0.unicodeScalars.allSatisfy { $0.value < 32 } }
        }
    }

    /// Remove trailing blank lines from string array
    private func removeTrailingBlankLines(_ lines: [String]) -> [String] {
        var result = lines
        while let last = result.last, isStringLineBlank(last) {
            result.removeLast()
        }
        return result
    }

    /// Check if a string line is blank (contains only whitespace or invisible characters)
    private func isStringLineBlank(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        // Empty after trimming, or contains only control characters (ASCII < 32)
        return trimmed.isEmpty || trimmed.allSatisfy { $0.isWhitespace || $0.unicodeScalars.allSatisfy { $0.value < 32 } }
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    if let styledLines = resolvedStyledLines, !styledLines.isEmpty {
                        // Render styled lines with full color support
                        ForEach(Array(styledLines.enumerated()), id: \.offset) { index, line in
                            TerminalLineView(line: line)
                                .frame(height: terminalLineHeight)
                        }
                        // Invisible anchor at bottom
                        Color.clear
                            .frame(width: 1, height: 1)
                            .id("bottom")
                    } else if let screenLines = session.screenLines, !screenLines.isEmpty {
                        // Fallback to plain text if no styled lines available
                        ForEach(Array(screenLines.enumerated()), id: \.offset) { index, line in
                            Text(line.isEmpty ? " " : line)
                                .font(terminalFont)
                                .foregroundColor(defaultForeground)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: terminalLineHeight)
                        }
                        // Invisible anchor at bottom
                        Color.clear
                            .frame(width: 1, height: 1)
                            .id("bottom")
                    } else {
                        // No content available
                        Text("No terminal content available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding(8)
            }
            .background(defaultBackground)
            .defaultScrollAnchor(.bottomLeading)
            .onChange(of: session.styledLines?.count ?? session.screenLines?.count ?? 0) { oldValue, newValue in
                // Auto-scroll to bottom-left when content updates
                DispatchQueue.main.async {
                    scrollProxy.scrollTo("bottom", anchor: .bottomLeading)
                }
            }
            .onAppear {
                // Scroll to bottom-left on initial load
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollProxy.scrollTo("bottom", anchor: .bottomLeading)
                }
            }
        }
    }
}

// MARK: - Terminal Session Card View

struct ITerm2SessionCardView: View {
    let session: ITerm2Session
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Session Header
            HStack {
                Circle()
                    .fill(session.isActive ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name)
                        .font(.headline)
                        .fontWeight(session.isActive ? .bold : .regular)

                    if let dir = session.currentDirectory {
                        Text(dir)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Terminal Content (expandable)
            if isExpanded {
                ITerm2TerminalView(session: session)
                    .frame(maxHeight: 400)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // Sample session with styled lines
        let sampleSession = ITerm2Session(
            sessionId: "preview-1",
            name: "zsh",
            currentDirectory: "/Users/developer/project",
            currentCommand: "git status",
            isActive: true,
            windowIndex: 0,
            tabIndex: 0,
            paneIndex: 0,
            screenLines: ["On branch main", "Your branch is up to date"],
            styledLines: [
                ITerm2StyledLine(
                    text: "On branch main",
                    characters: [
                        ITerm2Character(char: "O", fgColor: RGBColor(r: 255, g: 255, b: 255, a: 255), bgColor: nil, bold: false, italic: false, underline: false),
                        ITerm2Character(char: "n", fgColor: RGBColor(r: 255, g: 255, b: 255, a: 255), bgColor: nil, bold: false, italic: false, underline: false),
                        ITerm2Character(char: " ", fgColor: nil, bgColor: nil, bold: false, italic: false, underline: false),
                        ITerm2Character(char: "b", fgColor: RGBColor(r: 0, g: 255, b: 0, a: 255), bgColor: nil, bold: true, italic: false, underline: false),
                        ITerm2Character(char: "r", fgColor: RGBColor(r: 0, g: 255, b: 0, a: 255), bgColor: nil, bold: true, italic: false, underline: false),
                        ITerm2Character(char: "a", fgColor: RGBColor(r: 0, g: 255, b: 0, a: 255), bgColor: nil, bold: true, italic: false, underline: false),
                        ITerm2Character(char: "n", fgColor: RGBColor(r: 0, g: 255, b: 0, a: 255), bgColor: nil, bold: true, italic: false, underline: false),
                        ITerm2Character(char: "c", fgColor: RGBColor(r: 0, g: 255, b: 0, a: 255), bgColor: nil, bold: true, italic: false, underline: false),
                        ITerm2Character(char: "h", fgColor: RGBColor(r: 0, g: 255, b: 0, a: 255), bgColor: nil, bold: true, italic: false, underline: false),
                    ]
                )
            ]
        )

        ITerm2SessionCardView(session: sampleSession)
            .padding()
    }
    .background(Color(.systemGroupedBackground))
}
