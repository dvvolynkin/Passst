import AppKit
import Foundation

enum CodeDetector {
    static func isLikelyCode(_ value: String) -> Bool {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 8 else { return false }
        if text.hasPrefix("```") { return true }

        var score = 0
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        if matches(
            #"\b(?:actor|async|await|class|const|def|enum|extension|func|function|guard|import|interface|let|private|protocol|public|return|static|struct|switch|throw|typealias|var)\b"#,
            in: text
        ) {
            score += 3
        }
        if matches(#"(?:=>|==|!=|<=|>=|&&|\|\||::|:=)"#, in: text) {
            score += 2
        }
        if text.contains("{"), text.contains("}") {
            score += 2
        }
        if matches(#"(?m)^\s*(?://|#\s|/\*|\*|<!--)"#, in: text) {
            score += 2
        }
        if matches(#"(?m)^\s{2,}\S+"#, in: text), lines.count >= 2 {
            score += 2
        }
        if matches(
            #"(?m)^\s*(?:awk|brew|cat|cd|chmod|chown|cmake|cp|curl|docker|echo|find|gh|git|grep|kubectl|ls|make|mkdir|mv|npm|pnpm|printf|python|rm|rsync|ruby|scp|sed|ssh|swift|xcodebuild|yarn)\s+\S+"#,
            in: text,
            options: [.caseInsensitive]
        ) {
            score += 4
        }
        if matches(
            #"^(?:ssh-(?:rsa|ed25519)|-----BEGIN [A-Z ]+-----)"#,
            in: text,
            options: [.caseInsensitive]
        ) {
            score += 4
        }
        if matches(#"^\s*[\{\[][\s\S]*[\"'][^\"']+[\"']\s*:"#, in: text) {
            score += 4
        }
        if matches(#"</?[A-Za-z][^>]*>"#, in: text) {
            score += 3
        }
        if lines.count >= 3,
           lines.filter({ $0.hasSuffix(";") || $0.hasSuffix("{") }).count >= 2 {
            score += 2
        }

        return score >= 4
    }

    private static func matches(
        _ pattern: String,
        in value: String,
        options: NSRegularExpression.Options = []
    ) -> Bool {
        do {
            let expression = try NSRegularExpression(pattern: pattern, options: options)
            return expression.firstMatch(
                in: value,
                range: NSRange(value.startIndex..., in: value)
            ) != nil
        } catch {
            assertionFailure("Invalid code detection expression: \(error)")
            return false
        }
    }
}

enum CodeHighlighter {
    static func highlight(
        _ source: String,
        darkMode: Bool,
        fontSize: CGFloat
    ) async -> AttributedString {
        await Task.detached(priority: .userInitiated) {
            highlightSynchronously(
                source,
                darkMode: darkMode,
                fontSize: fontSize
            )
        }.value
    }

    private static func highlightSynchronously(
        _ source: String,
        darkMode: Bool,
        fontSize: CGFloat
    ) -> AttributedString {
        let value = NSMutableAttributedString(string: source)
        let fullRange = NSRange(location: 0, length: value.length)
        let palette = Palette(darkMode: darkMode)

        value.addAttributes(
            [
                .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: palette.foreground
            ],
            range: fullRange
        )

        apply(
            #"\b(?:actor|async|await|break|case|catch|class|const|continue|def|do|else|enum|export|extension|false|final|for|from|func|function|guard|if|import|in|interface|let|new|nil|null|private|protocol|public|return|self|static|struct|switch|this|throw|throws|true|try|typealias|var|while)\b"#,
            color: palette.keyword,
            to: value
        )
        apply(
            #"\b(?:[A-Z][A-Za-z0-9_]*)(?=\s*[<(]?)"#,
            color: palette.type,
            to: value
        )
        apply(
            #"\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b"#,
            color: palette.number,
            to: value
        )
        apply(
            #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#,
            color: palette.string,
            to: value
        )
        apply(
            #"(?m)//.*$|#(?![0-9A-Fa-f]{3,8}\b).*$|/\*[\s\S]*?\*/|<!--[\s\S]*?-->"#,
            color: palette.comment,
            to: value
        )

        return AttributedString(value)
    }

    private static func apply(
        _ pattern: String,
        color: NSColor,
        to value: NSMutableAttributedString
    ) {
        let expression: NSRegularExpression
        do {
            expression = try NSRegularExpression(pattern: pattern)
        } catch {
            assertionFailure("Invalid syntax highlighting expression: \(error)")
            return
        }
        let range = NSRange(location: 0, length: value.length)
        for match in expression.matches(in: value.string, range: range) {
            value.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }

    private struct Palette {
        let foreground: NSColor
        let keyword: NSColor
        let type: NSColor
        let number: NSColor
        let string: NSColor
        let comment: NSColor

        init(darkMode: Bool) {
            if darkMode {
                foreground = NSColor(red: 0.86, green: 0.89, blue: 0.94, alpha: 1)
                keyword = NSColor(red: 0.78, green: 0.58, blue: 0.91, alpha: 1)
                type = NSColor(red: 0.51, green: 0.74, blue: 1, alpha: 1)
                number = NSColor(red: 0.97, green: 0.55, blue: 0.42, alpha: 1)
                string = NSColor(red: 0.67, green: 0.82, blue: 0.48, alpha: 1)
                comment = NSColor(red: 0.45, green: 0.5, blue: 0.58, alpha: 1)
            } else {
                foreground = NSColor(red: 0.16, green: 0.18, blue: 0.22, alpha: 1)
                keyword = NSColor(red: 0.49, green: 0.25, blue: 0.61, alpha: 1)
                type = NSColor(red: 0.1, green: 0.42, blue: 0.7, alpha: 1)
                number = NSColor(red: 0.72, green: 0.31, blue: 0.1, alpha: 1)
                string = NSColor(red: 0.24, green: 0.47, blue: 0.12, alpha: 1)
                comment = NSColor(red: 0.46, green: 0.5, blue: 0.56, alpha: 1)
            }
        }
    }
}
