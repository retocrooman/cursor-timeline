import Foundation

public enum BuildInfo {
    public static var bundleVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "dev"
    }
}
