import Foundation

public enum ModelNormalizer {
    public static func normalize(_ raw: String?) -> ModelFamily {
        let lower = raw?.lowercased() ?? ""
        if lower.contains("opus") { return .opus }
        if lower.contains("sonnet") { return .sonnet }
        if lower.contains("composer") { return .composer }
        if lower.contains("gpt") { return .gpt }
        return .other
    }
}
