import Foundation

public struct ProjectName: Equatable, Sendable {
    public var yymmdd: String
    public var description: String
    public var bpm: Int

    public init(yymmdd: String, description: String, bpm: Int) {
        self.yymmdd = yymmdd
        self.description = description
        self.bpm = bpm
    }

    public var sanitizedDescription: String {
        Self.sanitize(description)
    }

    public var bpmLabel: String {
        bpm == 0 ? "000" : String(bpm)
    }

    public var folderName: String {
        "\(yymmdd)_\(sanitizedDescription)_\(bpmLabel)"
    }

    public var isValid: Bool {
        yymmdd.range(of: #"^\d{6}$"#, options: .regularExpression) != nil
            && !sanitizedDescription.isEmpty
            && Self.isAllowedBPM(bpm)
    }

    public static func isAllowedBPM(_ bpm: Int) -> Bool {
        bpm == 0 || (20...300).contains(bpm)
    }

    public static func pascalCaseWords(_ raw: String) -> String {
        raw.split(whereSeparator: \.isWhitespace).map { word in
            let value = String(word)
            guard let first = value.first else { return value }
            return String(first).uppercased() + value.dropFirst()
        }.joined()
    }

    public static func removingSpaces(from displayName: String, bpm overrideBPM: Int? = nil) -> String? {
        let logicSuffix = ".logicx"
        let hasLogic = displayName.lowercased().hasSuffix(logicSuffix)
        let stem = hasLogic ? String(displayName.dropLast(logicSuffix.count)) : displayName
        let hasSpaces = stem.contains(where: \.isWhitespace)
        guard hasSpaces || overrideBPM != nil else { return nil }

        let rebuilt: String
        if let parsed = parse(stem), !parsed.description.isEmpty {
            let description = pascalCaseWords(parsed.description)
            if let bpm = overrideBPM ?? parsed.bpm {
                rebuilt = "\(parsed.yymmdd)_\(description)_\(Self.bpmLabel(bpm))"
            } else {
                rebuilt = "\(parsed.yymmdd)_\(description)"
            }
        } else {
            let base = pascalCaseWords(stem)
            if let bpm = overrideBPM {
                let suffix = "_\(Self.bpmLabel(bpm))"
                rebuilt = base.hasSuffix(suffix) ? base : base + suffix
            } else {
                rebuilt = base
            }
        }
        guard !rebuilt.isEmpty, rebuilt != stem else { return nil }
        return hasLogic ? rebuilt + String(displayName.suffix(logicSuffix.count)) : rebuilt
    }

    public static func bpmLabel(_ bpm: Int) -> String {
        bpm == 0 ? "000" : String(bpm)
    }

    public static func sanitize(_ raw: String) -> String {
        let stripped = raw
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "\\", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "\0", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
        let collapsed = stripped
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return collapsed
    }

    public static func yymmdd(from date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = (parts.year ?? 0) % 100
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%02d%02d%02d", year, month, day)
    }

    public static func defaultDate(
        fromDisplayName displayName: String,
        oldest: Date,
        calendar: Calendar = .current
    ) -> String {
        if let parsed = parse(displayName) {
            return parsed.yymmdd
        }
        let prefix = String(displayName.prefix(6))
        if prefix.range(of: #"^\d{6}$"#, options: .regularExpression) != nil,
           displayName.count == 6 || displayName.dropFirst(6).first == "_" {
            return prefix
        }
        return yymmdd(from: oldest, calendar: calendar)
    }

    /// `YYMMDD_Name_BPM`, e.g. `260323_underwater guitar_92` or `260323_drone wash_000`.
    public static func matchesNamingScheme(_ folderName: String) -> Bool {
        guard let parsed = parse(folderName), let bpm = parsed.bpm else { return false }
        return ProjectName(yymmdd: parsed.yymmdd, description: parsed.description, bpm: bpm).isValid
    }

    public static func parse(_ folderName: String) -> (yymmdd: String, description: String, bpm: Int?)? {
        var value = folderName
        if value.lowercased().hasSuffix(".logicx") {
            value = String(value.dropLast(".logicx".count))
        }
        let ns = value as NSString
        guard let match = namePattern.firstMatch(in: value, options: [], range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges >= 3,
              let dateRange = Range(match.range(at: 1), in: value),
              let restRange = Range(match.range(at: 2), in: value)
        else {
            return nil
        }

        let yymmdd = String(value[dateRange])
        var rest = String(value[restRange])
        var bpm: Int?
        if let bpmMatch = rest.range(of: #"_\d{2,3}$"#, options: .regularExpression) {
            let digits = rest[bpmMatch].dropFirst()
            if let parsed = Int(digits), isAllowedBPM(parsed) {
                bpm = parsed
                rest.removeSubrange(bpmMatch)
            }
        }

        let description = UnnamedDetector.isUnnamed(rest) ? "" : sanitize(rest)
        return (yymmdd, description, bpm)
    }

    private static let namePattern = try! NSRegularExpression(
        pattern: #"^(\d{6})_(.+)$"#,
        options: []
    )
}
