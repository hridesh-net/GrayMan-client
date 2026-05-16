import Foundation

struct Worker: Identifiable, Hashable, Sendable {
    let id: Int
    let initials: String
    let name: String
    let trade: String
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
}

extension Worker {
    // Category string used by the Explore filter (same as trade).
    var category: String { trade }

    static let samples: [Worker] = [
        Worker(id: 1, initials: "RK", name: "Rajesh Kumar", trade: "Electrician",
               location: "Andheri · 3.2 km", distanceKm: 3.2,
               vouched: 84, vouchScore: 84, jobs: 38, rating: "4.8",
               tags: ["Wiring", "Panel", "Industrial"], verifiedTagIndices: [0, 1],
               emoji: "⚡", gradientStartHex: "#0c1829", gradientEndHex: "#1a3355"),

        Worker(id: 2, initials: "PS", name: "Priya Sharma", trade: "Interior Decorator",
               location: "Bandra · 7.8 km", distanceKm: 7.8,
               vouched: 91, vouchScore: 91, jobs: 62, rating: "4.9",
               tags: ["Decor", "Renovation", "Luxury"], verifiedTagIndices: [0],
               emoji: "🎨", gradientStartHex: "#1e0f05", gradientEndHex: "#3d2210"),

        Worker(id: 3, initials: "AM", name: "Arjun Mehta", trade: "Plumber",
               location: "Malad · 12.1 km", distanceKm: 12.1,
               vouched: 76, vouchScore: 76, jobs: 29, rating: "4.7",
               tags: ["Plumbing", "Leakfix", "Bathroom"], verifiedTagIndices: [0],
               emoji: "🔧", gradientStartHex: "#081420", gradientEndHex: "#102840"),

        Worker(id: 4, initials: "SK", name: "Sunita Kaur", trade: "HVAC Technician",
               location: "Goregaon · 18 km", distanceKm: 18,
               vouched: 88, vouchScore: 88, jobs: 45, rating: "4.9",
               tags: ["HVAC", "AC Repair", "Cooling"], verifiedTagIndices: [0, 1],
               emoji: "❄️", gradientStartHex: "#061a0e", gradientEndHex: "#0c3018"),

        Worker(id: 5, initials: "VR", name: "Vikram Rao", trade: "Welder",
               location: "Thane · 35 km", distanceKm: 35,
               vouched: 79, vouchScore: 79, jobs: 54, rating: "4.6",
               tags: ["Welding", "Fabrication", "Gates"], verifiedTagIndices: [0],
               emoji: "🔥", gradientStartHex: "#1a0800", gradientEndHex: "#361400"),

        Worker(id: 6, initials: "MA", name: "Meena Agarwal", trade: "Home Nurse",
               location: "Navi Mumbai · 52 km", distanceKm: 52,
               vouched: 95, vouchScore: 95, jobs: 80, rating: "5.0",
               tags: ["Nursing", "Elder Care", "ICU"], verifiedTagIndices: [0, 1, 2],
               emoji: "🏥", gradientStartHex: "#0e0718", gradientEndHex: "#1c1030"),
    ]

    static let radiusSteps: [Int] = [5, 10, 15, 20, 30, 40, 50, 60, 75, 100]

    static var allCategories: [String] {
        ["All"] + Array(Set(samples.map(\.trade))).sorted()
    }
}
