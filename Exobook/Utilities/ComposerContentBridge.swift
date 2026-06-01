//
//  ComposerContentBridge.swift
//  Exobook
//
//  Created by GPT-5.3-Codex on 10/05/2026.
//

import Foundation

extension String {
    /// Bridges plain composer text into lightweight HTML so web and iOS render consistently.
    /// - If content already contains HTML tags, it is returned unchanged (trimmed).
    /// - Plain text is escaped and line breaks are converted to paragraph / `<br>` markup.
    var bridgedComposerHTML: String {
        let normalized = self
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return "" }

        // Avoid double-wrapping when content is already HTML.
        if normalized.range(of: #"</?[A-Za-z][^>]*>"#, options: .regularExpression) != nil {
            return normalized
        }

        let markdownHTML = normalized.markdownLikeHTML
        if !markdownHTML.isEmpty {
            return markdownHTML
        }

        var escaped = normalized
        escaped = escaped.htmlEscaped

        let htmlBody = escaped
            .replacingOccurrences(of: "\n\n", with: "</p><p>")
            .replacingOccurrences(of: "\n", with: "<br>")

        return "<p>\(htmlBody)</p>"
    }

    private var markdownLikeHTML: String {
        let lines = self
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        guard lines.contains(where: String.containsMarkdownSyntax) else {
            return ""
        }

        var htmlBlocks: [String] = []
        var currentListItems: [String] = []
        var currentListTag: String?
        var currentParagraphLines: [String] = []

        func flushParagraph() {
            guard !currentParagraphLines.isEmpty else { return }
            let paragraph = currentParagraphLines
                .map { $0.inlineMarkdownHTML }
                .joined(separator: "<br>")
            htmlBlocks.append("<p>\(paragraph)</p>")
            currentParagraphLines.removeAll()
        }

        func flushList() {
            guard let tag = currentListTag, !currentListItems.isEmpty else { return }
            let items = currentListItems.map { "<li>\($0)</li>" }.joined()
            htmlBlocks.append("<\(tag)>\(items)</\(tag)>")
            currentListItems.removeAll()
            currentListTag = nil
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flushParagraph()
                flushList()
                continue
            }

            if let heading = line.headingHTML {
                flushParagraph()
                flushList()
                htmlBlocks.append(heading)
                continue
            }

            if let quote = line.blockquoteHTML {
                flushParagraph()
                flushList()
                htmlBlocks.append(quote)
                continue
            }

            if let (tag, item) = line.listItemHTML {
                flushParagraph()
                if currentListTag != tag {
                    flushList()
                    currentListTag = tag
                }
                currentListItems.append(item)
                continue
            }

            flushList()
            currentParagraphLines.append(line)
        }

        flushParagraph()
        flushList()

        return htmlBlocks.joined()
    }

    private static func containsMarkdownSyntax(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }

        if trimmed.hasPrefix("#")
            || trimmed.hasPrefix("> ")
            || trimmed.hasPrefix("- ")
            || trimmed.hasPrefix("* ")
            || trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
            return true
        }

        return trimmed.contains("**")
            || trimmed.contains("*")
            || trimmed.contains("`")
            || trimmed.range(of: #"\[[^\]]+\]\([^)]+\)"#, options: .regularExpression) != nil
    }

    private var headingHTML: String? {
        for level in 1...3 {
            let prefix = String(repeating: "#", count: level) + " "
            if hasPrefix(prefix) {
                let value = String(dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                return "<h\(level)>\(value.inlineMarkdownHTML)</h\(level)>"
            }
        }
        return nil
    }

    private var blockquoteHTML: String? {
        guard hasPrefix("> ") else { return nil }
        return "<blockquote><p>\(String(dropFirst(2)).inlineMarkdownHTML)</p></blockquote>"
    }

    private var listItemHTML: (tag: String, item: String)? {
        if hasPrefix("- ") || hasPrefix("* ") {
            return ("ul", String(dropFirst(2)).inlineMarkdownHTML)
        }

        guard let range = range(of: #"^\d+\.\s"#, options: .regularExpression) else {
            return nil
        }

        let value = String(self[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        return ("ol", value.inlineMarkdownHTML)
    }

    private var inlineMarkdownHTML: String {
        var html = htmlEscaped

        let replacements: [(String, String)] = [
            (#"\[([^\]]+)\]\((https?://[^)]+)\)"#, #"<a href="$2">$1</a>"#),
            (#"\*\*([^*]+)\*\*"#, #"<strong>$1</strong>"#),
            (#"(?<!\*)\*([^*\n]+)\*(?!\*)"#, #"<em>$1</em>"#),
            (#"`([^`\n]+)`"#, #"<code>$1</code>"#)
        ]

        for (pattern, template) in replacements {
            html = html.replacingOccurrences(
                of: pattern,
                with: template,
                options: .regularExpression
            )
        }

        return html
    }

    private var htmlEscaped: String {
        var escaped = self
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&#39;")
        return escaped
    }
}
