//
//  HTMLRendering.swift
//

import Foundation
import SwiftUI

extension String {

    // MARK: - Strip HTML to plain text

    var htmlStripped: String {
        var result = self
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&amp;",  with: "&")
        result = result.replacingOccurrences(of: "&lt;",   with: "<")
        result = result.replacingOccurrences(of: "&gt;",   with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;",  with: "'")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - HTML → AttributedString (no WebKit, no crash)

    func htmlAttributedString(fontSize: CGFloat) -> AttributedString {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return AttributedString() }
        return HTMLParser.parse(trimmed, fontSize: fontSize)
    }
}

// MARK: - Pure-Swift HTML parser

private enum HTMLParser {

    static func parse(_ html: String, fontSize: CGFloat) -> AttributedString {
        var result = AttributedString()
        let baseFont = UIFont.systemFont(ofSize: fontSize)
        let boldFont  = UIFont.boldSystemFont(ofSize: fontSize)
        let italicFont = UIFont(
            descriptor: baseFont.fontDescriptor.withSymbolicTraits(.traitItalic) ?? baseFont.fontDescriptor,
            size: fontSize
        )

        // Tokenise into runs of text and tags
        let tokens = tokenise(html)

        var isBold   = false
        var isItalic = false
        var pendingListItem = false
        var inOrderedList  = false
        var orderedIndex   = 1

        for token in tokens {
            switch token {

            case .text(let raw):
                let unescaped = unescape(raw)
                guard !unescaped.isEmpty else { continue }
                var chunk = AttributedString(unescaped)
                let font: UIFont = isBold ? boldFont : (isItalic ? italicFont : baseFont)
                chunk.uiKit.font = font
                result.append(chunk)

            case .tag(let name, let closing, _):
                switch name.lowercased() {

                case "strong", "b":
                    isBold = !closing

                case "em", "i":
                    isItalic = !closing

                case "br":
                    result.append(AttributedString("\n"))

                case "p":
                    if closing && !result.characters.isEmpty {
                        result.append(AttributedString("\n\n"))
                    }

                case "ul":
                    inOrderedList = false
                    if closing { result.append(AttributedString("\n")) }

                case "ol":
                    inOrderedList = !closing
                    orderedIndex  = 1
                    if closing { result.append(AttributedString("\n")) }

                case "li":
                    if !closing {
                        let bullet = inOrderedList ? "\(orderedIndex). " : "• "
                        if inOrderedList { orderedIndex += 1 }
                        var bulletChunk = AttributedString(bullet)
                        bulletChunk.uiKit.font = baseFont
                        result.append(bulletChunk)
                        pendingListItem = true
                    } else {
                        result.append(AttributedString("\n"))
                        pendingListItem = false
                    }

                case "h1", "h2", "h3":
                    if closing { result.append(AttributedString("\n\n")) }
                    isBold = !closing

                default:
                    break
                }
            }
        }

        // Trim trailing whitespace/newlines
        var final = result
        while final.characters.last?.isNewline == true || final.characters.last == "\n" {
            final.characters.removeLast()
        }
        return final
    }

    // MARK: Tokeniser

    enum Token {
        case text(String)
        case tag(name: String, closing: Bool, attributes: String)
    }

    static func tokenise(_ html: String) -> [Token] {
        var tokens: [Token] = []
        var remaining = html[...]

        while !remaining.isEmpty {
            if let tagStart = remaining.firstIndex(of: "<") {
                // Text before the tag
                let textPart = String(remaining[remaining.startIndex..<tagStart])
                if !textPart.isEmpty {
                    tokens.append(.text(textPart))
                }
                remaining = remaining[tagStart...]

                // Find closing >
                if let tagEnd = remaining.firstIndex(of: ">") {
                    let tagContent = String(remaining[remaining.index(after: remaining.startIndex)..<tagEnd])
                    remaining = remaining[remaining.index(after: tagEnd)...]

                    let closing = tagContent.hasPrefix("/")
                    let inner   = closing ? String(tagContent.dropFirst()) : tagContent
                    let parts   = inner.split(maxSplits: 1, whereSeparator: { $0 == " " })
                    let name    = parts.first.map(String.init) ?? inner
                    let attrs   = parts.count > 1 ? String(parts[1]) : ""

                    // Skip comments and doctype
                    if !name.hasPrefix("!") && !name.hasPrefix("?") {
                        tokens.append(.tag(name: name, closing: closing, attributes: attrs))
                    }
                } else {
                    // Unclosed tag — treat rest as text
                    tokens.append(.text(String(remaining)))
                    break
                }
            } else {
                tokens.append(.text(String(remaining)))
                break
            }
        }

        return tokens
    }

    // MARK: HTML entity unescape

    static func unescape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;",  with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
    }
}
