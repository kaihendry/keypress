import Foundation

struct BuildInfo {
    // Initialized at launch, before a later install can replace the bundle's plist.
    static let current = BuildInfo()

    let version: String
    let revision: String

    private init() {
        version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        revision = Bundle.main.object(forInfoDictionaryKey: "KeypressGitRevision") as? String ?? "unknown"
    }

    var label: String { "v\(version) · git \(revision)" }
}
