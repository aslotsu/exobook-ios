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

        var escaped = normalized
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&#39;")

        let htmlBody = escaped
            .replacingOccurrences(of: "\n\n", with: "</p><p>")
            .replacingOccurrences(of: "\n", with: "<br>")

        return "<p>\(htmlBody)</p>"
    }
}
