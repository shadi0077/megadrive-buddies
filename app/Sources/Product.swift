import Foundation

/// Which app this build is.
///
/// A product is a manifest in `products/`: a name, a bundle identifier, and the
/// cast that ships with it. The build copies only that cast's sprites and the
/// app filters its roster to match, so a second app — a different roster, or
/// one game's characters on their own — is a JSON file rather than a target.
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
}
