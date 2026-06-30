import Foundation

enum LaunchGateConfiguration {
    static let remoteGateURLString: String = "https://plantcorner.org/click.php"
    static let blockedURLMarker: String = "termsfeed"

    static var trimmedRemoteGateURLString: String {
        remoteGateURLString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var remoteGateURL: URL? {
        let s = trimmedRemoteGateURLString
        guard !s.isEmpty else { return nil }
        return URL(string: s)
    }

    static var blockedMarkerLowercased: String {
        blockedURLMarker.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func urlContainsBlockedMarker(_ url: URL?) -> Bool {
        guard let url else { return false }
        let marker = blockedMarkerLowercased
        guard !marker.isEmpty else { return false }
        return url.absoluteString.lowercased().contains(marker)
    }
}
