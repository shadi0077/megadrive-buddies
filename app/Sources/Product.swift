import Foundation

/// Which app this build is, and who ships with it.
///
/// The cast lives in a manifest rather than in the sources, so adding a
/// character to the app is a line of JSON and a sprite folder — the build
/// copies only the characters the manifest names.
struct Product {
    let id: String
    let name: String
    let tagline: String
    let cast: [String]
    let credit: String

    /// The manifest bundled with this build.
    static let current: Product = {
        // Test tools run outside any app bundle, so they say which product
        // they're exercising; the app itself reads its own manifest.
        let override = ProcessInfo.processInfo.environment["BUDDY_PRODUCT"]
            .map(URL.init(fileURLWithPath:))
        guard let url = override
                ?? Bundle.main.url(forResource: "product", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = root["id"] as? String,
              let name = root["name"] as? String,
              let cast = root["cast"] as? [String]
        else {
            // A build with no manifest still runs, with whoever is bundled.
            return Product(id: "unknown", name: "Buddies", tagline: "",
                           cast: [], credit: "")
        }
        return Product(id: id, name: name,
                       tagline: root["tagline"] as? String ?? "",
                       cast: cast,
                       credit: root["credit"] as? String ?? "")
    }()

    /// True when nobody in this product can talk out loud — which decides
    /// whether the menu offers songs and voices, or a fight.
    var isSilent: Bool {
        !Personality.all.contains { $0.speaks }
    }
}
