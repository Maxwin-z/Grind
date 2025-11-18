#!/usr/bin/env swift

import Foundation

// Test script to verify color data structures

struct RGBColor: Codable {
    let r: Int
    let g: Int
    let b: Int
    let a: Int
}

struct ITerm2Character: Codable {
    let char: String
    let fgColor: RGBColor?
    let bgColor: RGBColor?
    let bold: Bool
    let italic: Bool
    let underline: Bool

    enum CodingKeys: String, CodingKey {
        case char
        case fgColor = "fg_color"
        case bgColor = "bg_color"
        case bold
        case italic
        case underline
    }
}

struct ITerm2StyledLine: Codable {
    let text: String
    let characters: [ITerm2Character]
}

// Sample JSON from Python script
let sampleJSON = """
{
    "text": "Hello World",
    "characters": [
        {
            "char": "H",
            "fg_color": {"r": 255, "g": 0, "b": 0, "a": 255},
            "bg_color": null,
            "bold": true,
            "italic": false,
            "underline": false
        },
        {
            "char": "e",
            "fg_color": {"r": 255, "g": 255, "b": 255, "a": 255},
            "bg_color": null,
            "bold": false,
            "italic": false,
            "underline": false
        }
    ]
}
"""

let decoder = JSONDecoder()
do {
    let data = sampleJSON.data(using: .utf8)!
    let styledLine = try decoder.decode(ITerm2StyledLine.self, from: data)
    print("✅ Successfully decoded styled line:")
    print("   Text: \(styledLine.text)")
    print("   Characters: \(styledLine.characters.count)")

    for (index, char) in styledLine.characters.enumerated() {
        print("   [\(index)] '\(char.char)' - Bold: \(char.bold), FG: \(char.fgColor != nil ? "RGB(\(char.fgColor!.r),\(char.fgColor!.g),\(char.fgColor!.b))" : "nil")")
    }
} catch {
    print("❌ Decoding failed: \(error)")
}
