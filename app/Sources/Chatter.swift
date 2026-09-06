import Foundation

/// The few lines that read the same in either mouth. Everything with a voice
/// to it lives in Personality.
/// Remembers the last few picks so he doesn't say the same thing twice running.
///
/// Without this he repeats himself constantly — a short pool plus uniform
/// random means the same line three pokes in a row, which is the single most
/// robot-like thing either of them does.
struct RecentPicks {
    private var seen: [String] = []
    let limit: Int

    init(limit: Int) { self.limit = limit }

    mutating func pick(from pool: [String]) -> String {
        guard !pool.isEmpty else { return "" }
        let unused = pool.filter { !seen.contains($0) }
        // If everything is stale, allow the whole pool again but keep the very
        // last pick out of the running.
        let candidates = unused.isEmpty ? pool.filter { $0 != seen.last } : unused
        let choice = (candidates.isEmpty ? pool : candidates).randomElement()!
        seen.append(choice)
        if seen.count > limit { seen.removeFirst() }
        return choice
    }
}

extension Double {
    func clamped(to range: Range<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound.nextDown)
    }
}
