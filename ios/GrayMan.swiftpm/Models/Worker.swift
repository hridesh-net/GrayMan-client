import Foundation

struct Worker: Identifiable, Hashable, Sendable {
    let id: String                    // backend UUID (string)
    let initials: String
    let name: String
    let trade: String
    let phone: String                 // e.164 format, used for call / WhatsApp deep links
    let bio: String?
    let location: String              // "Andheri · 3.2 km"
    let distanceKm: Double
    let vouched: Int                  // raw endorsement count
    let vouchScore: Int               // 1–100 composite trust score (doc §2C)
    let jobs: Int
    let rating: String                // pre-formatted "4.8"
    let tags: [String]
    let verifiedTagIndices: Set<Int>  // indices in tags that carry a skill badge
    let emoji: String
    let gradientStartHex: String
    let gradientEndHex: String
    let isVerified: Bool              // reel-verified profile badge
    let avatarURL: String?            // optional profile picture (S3 public URL)
}

extension Worker {
    var category: String { trade }

    /// Radius steps for the Explore radius pill. Picked to match a typical
    /// city-radius range; larger steps as the radius grows.
    static let radiusSteps: [Int] = [5, 10, 15, 20, 30, 40, 50, 60, 75, 100]

    /// Static category list shown in the Explore filter bar. Mirrors the
    /// trades the backend recognises (`KNOWN_TRADES` in
    /// `app/schemas/worker.py`).
    static let allCategories: [String] = [
        "All",
        "Electrician",
        "Plumber",
        "Carpenter",
        "Painter",
        "Mason",
        "Welder",
        "Mechanic",
        "Driver",
        "Cook",
        "Nurse",
        "Tailor",
        "AC Technician",
        "Interior Decorator",
        "Appliance Repair",
        "Gardener",
        "Security Guard",
        "Other",
    ]
}
