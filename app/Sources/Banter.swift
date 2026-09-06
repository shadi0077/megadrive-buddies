import Foundation

/// The speaking characters' two-handers.
///
/// Empty here: this app's cast has no voices, so there is nothing for them to
/// say to each other in words. The real dialogue lives in the shared repository
/// with the characters it belongs to; see `tools/publish.py`.
struct BanterLine {
    let who: String
    let text: String
    let move: String?
}

enum Banter {
    static let exchanges: [[BanterLine]] = []
    static let arabicExchanges: [[BanterLine]] = []
    static let anyPair: [[BanterLine]] = []
    static let anyPairArabic: [[BanterLine]] = []
    static func all(in language: Language) -> [[BanterLine]] { [] }
    static func available(for cast: Set<String>, in language: Language) -> [[BanterLine]] { [] }
}
