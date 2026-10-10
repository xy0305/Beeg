import Foundation

enum BeegCatalog {
    static let pageSize = 12
    static let minimumPageSize = 10

    static func displayName(_ raw: String) -> String {
        raw.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
    }

    static func compactCount(_ value: Int) -> String {
        let number = Double(value)
        if number >= 1_000_000 {
            return trim(number / 1_000_000) + "M"
        }
        if number >= 1_000 {
            return trim(number / 1_000) + "K"
        }
        return "\(value)"
    }

    static func duration(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        return String(format: "%d:%02d", safe / 60, safe % 60)
    }

    static func relativeDate(_ iso: String, now: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return "" }
        let days = Calendar.current.dateComponents([.day], from: date, to: now).day ?? 0
        if days <= 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days)d" }
        return "\(days / 7)w"
    }

    static func masterPlaylist(template: String, fileID: Int) -> URL? {
        let trimmed = template.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains(".m3u8"), !trimmed.contains(".."), !trimmed.contains("://") else { return nil }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .beegPath) ?? trimmed
        return URL(string: "https://video.beeg.com/\(encoded)")
    }

    static func variants(_ playlist: String) -> [(label: String, path: String)] {
        let rows = playlist.components(separatedBy: .newlines)
        var found: [(height: Int, bandwidth: Int, path: String)] = []
        for index in rows.indices where rows[index].contains("#EXT-X-STREAM-INF") {
            guard index + 1 < rows.count else { continue }
            let path = rows[index + 1].trimmingCharacters(in: .whitespaces)
            guard path.hasPrefix("/"), !path.contains("://"), !path.contains("..") else { continue }
            let bandwidth = capture(#"BANDWIDTH=(\d+)"#, in: rows[index]).flatMap(Int.init) ?? 0
            let height = capture(#"RESOLUTION=\d+x(\d+)"#, in: rows[index]).flatMap(Int.init) ?? 0
            found.append((height, bandwidth, path))
        }
        return found
            .sorted { lhs, rhs in
                if lhs.height == rhs.height { return lhs.bandwidth > rhs.bandwidth }
                return lhs.height > rhs.height
            }
            .map { (label: $0.height > 0 ? "\($0.height)p" : "\($0.bandwidth)", path: $0.path) }
            .reduce(into: [(label: String, path: String)]()) { result, item in
                guard !result.contains(where: { $0.label == item.label }) else { return }
                result.append(item)
            }
    }

    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let text = error.localizedDescription.lowercased()
        return text == "cancelled" || text == "canceled"
    }

    static func preferredVariant(_ playlist: String) -> String? {
        variants(playlist).first?.path
    }

    private static func trim(_ value: Double) -> String {
        let text = String(format: "%.1f", value)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }

    private static func capture(_ pattern: String, in text: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let found = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[found])
    }
}

private extension CharacterSet {
    static let beegPath = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~/:?=,+")
}
