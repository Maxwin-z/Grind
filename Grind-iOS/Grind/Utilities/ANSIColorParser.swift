//
//  ANSIColorParser.swift
//  Grind
//
//  Parses ANSI escape sequences (SGR codes) into styled terminal characters.
//

import Foundation

struct ANSIColorParser {
    private struct StyleState {
        var fgColor: RGBColor?
        var bgColor: RGBColor?
        var bold = false
        var italic = false
        var underline = false

        mutating func apply(code: Int, remainingCodes: [Int], currentIndex: inout Int) {
            switch code {
            case 0:
                fgColor = nil
                bgColor = nil
                bold = false
                italic = false
                underline = false
            case 1:
                bold = true
            case 3:
                italic = true
            case 4:
                underline = true
            case 22:
                bold = false
            case 23:
                italic = false
            case 24:
                underline = false
            case 30...37:
                fgColor = ANSIColorParser.color(forBasicIndex: code - 30, bright: false)
            case 90...97:
                fgColor = ANSIColorParser.color(forBasicIndex: code - 90, bright: true)
            case 40...47:
                bgColor = ANSIColorParser.color(forBasicIndex: code - 40, bright: false)
            case 100...107:
                bgColor = ANSIColorParser.color(forBasicIndex: code - 100, bright: true)
            case 38:
                applyExtendedColor(isForeground: true, remainingCodes: remainingCodes, currentIndex: &currentIndex)
            case 48:
                applyExtendedColor(isForeground: false, remainingCodes: remainingCodes, currentIndex: &currentIndex)
            case 39:
                fgColor = nil
            case 49:
                bgColor = nil
            default:
                break
            }
        }

        private mutating func applyExtendedColor(isForeground: Bool, remainingCodes: [Int], currentIndex: inout Int) {
            guard currentIndex + 1 < remainingCodes.count else { return }
            let mode = remainingCodes[currentIndex + 1]

            switch mode {
            case 2: // True color: 38;2;R;G;B
                guard currentIndex + 4 < remainingCodes.count else { return }
                let r = clampColorComponent(remainingCodes[currentIndex + 2])
                let g = clampColorComponent(remainingCodes[currentIndex + 3])
                let b = clampColorComponent(remainingCodes[currentIndex + 4])
                let color = RGBColor(r: r, g: g, b: b, a: 255)
                if isForeground {
                    fgColor = color
                } else {
                    bgColor = color
                }
                currentIndex += 4
            case 5: // 256-color palette
                guard currentIndex + 2 < remainingCodes.count else { return }
                let paletteIndex = remainingCodes[currentIndex + 2]
                if let color = ANSIColorParser.color(forExtendedIndex: paletteIndex) {
                    if isForeground {
                        fgColor = color
                    } else {
                        bgColor = color
                    }
                }
                currentIndex += 2
            default:
                break
            }
        }
    }

    static func styledLines(from rawLines: [String]) -> [ITerm2StyledLine] {
        rawLines.map { line in
            let (text, characters) = parseLine(line)
            return ITerm2StyledLine(text: text, characters: characters)
        }
    }

    private static func parseLine(_ line: String) -> (String, [ITerm2Character]) {
        var state = StyleState()
        var characters: [ITerm2Character] = []
        var visibleText = ""

        var index = line.startIndex
        while index < line.endIndex {
            let char = line[index]

            if char == "\u{001B}" {
                index = line.index(after: index)
                guard index < line.endIndex, line[index] == "[" else {
                    continue
                }

                index = line.index(after: index)
                var codes: [Int] = []
                var currentNumber = ""
                var sequenceTerminated = false

                while index < line.endIndex {
                    let token = line[index]
                    if token == ";" {
                        if let value = Int(currentNumber) {
                            codes.append(value)
                        } else if currentNumber.isEmpty {
                            codes.append(0)
                        }
                        currentNumber.removeAll()
                    } else if token == "m" {
                        if let value = Int(currentNumber) {
                            codes.append(value)
                        } else if currentNumber.isEmpty {
                            codes.append(0)
                        }
                        currentNumber.removeAll()
                        sequenceTerminated = true
                        index = line.index(after: index)
                        break
                    } else if token.isNumber {
                        currentNumber.append(token)
                    } else {
                        // Unsupported token, break out to avoid infinite loops
                        index = line.index(after: index)
                        break
                    }
                    index = line.index(after: index)
                }

                if sequenceTerminated {
                    var codeIndex = 0
                    while codeIndex < codes.count {
                        state.apply(code: codes[codeIndex], remainingCodes: codes, currentIndex: &codeIndex)
                        codeIndex += 1
                    }
                }

                continue
            }

            visibleText.append(char)
            characters.append(
                ITerm2Character(
                    char: String(char),
                    fgColor: state.fgColor,
                    bgColor: state.bgColor,
                    bold: state.bold,
                    italic: state.italic,
                    underline: state.underline
                )
            )

            index = line.index(after: index)
        }

        return (visibleText, characters)
    }

    private static func color(forBasicIndex index: Int, bright: Bool) -> RGBColor {
        let palette = bright ? ANSIColorPalette.bright : ANSIColorPalette.basic
        let safeIndex = max(0, min(palette.count - 1, index))
        return palette[safeIndex]
    }

    private static func color(forExtendedIndex index: Int) -> RGBColor? {
        switch index {
        case 0...15:
            if index < 8 {
                return ANSIColorPalette.basic[index]
            }
            return ANSIColorPalette.bright[index - 8]
        case 16...231:
            let value = index - 16
            let r = value / 36
            let g = (value % 36) / 6
            let b = value % 6
            return RGBColor(
                r: colorComponent(for: r),
                g: colorComponent(for: g),
                b: colorComponent(for: b),
                a: 255
            )
        case 232...255:
            let gray = 8 + 10 * (index - 232)
            return RGBColor(r: gray, g: gray, b: gray, a: 255)
        default:
            return nil
        }
    }

    private static func colorComponent(for level: Int) -> Int {
        guard level > 0 else { return 0 }
        return 95 + (level - 1) * 40
    }

    private static func clampColorComponent(_ value: Int) -> Int {
        max(0, min(255, value))
    }
}

private enum ANSIColorPalette {
    static let basic: [RGBColor] = [
        RGBColor(r: 0, g: 0, b: 0, a: 255),         // Black
        RGBColor(r: 205, g: 0, b: 0, a: 255),       // Red
        RGBColor(r: 0, g: 205, b: 0, a: 255),       // Green
        RGBColor(r: 205, g: 205, b: 0, a: 255),     // Yellow
        RGBColor(r: 0, g: 0, b: 238, a: 255),       // Blue
        RGBColor(r: 205, g: 0, b: 205, a: 255),     // Magenta
        RGBColor(r: 0, g: 205, b: 205, a: 255),     // Cyan
        RGBColor(r: 229, g: 229, b: 229, a: 255)    // White
    ]

    static let bright: [RGBColor] = [
        RGBColor(r: 127, g: 127, b: 127, a: 255),   // Bright Black (Gray)
        RGBColor(r: 255, g: 0, b: 0, a: 255),       // Bright Red
        RGBColor(r: 0, g: 255, b: 0, a: 255),       // Bright Green
        RGBColor(r: 255, g: 255, b: 0, a: 255),     // Bright Yellow
        RGBColor(r: 92, g: 92, b: 255, a: 255),     // Bright Blue
        RGBColor(r: 255, g: 0, b: 255, a: 255),     // Bright Magenta
        RGBColor(r: 0, g: 255, b: 255, a: 255),     // Bright Cyan
        RGBColor(r: 255, g: 255, b: 255, a: 255)    // Bright White
    ]
}
