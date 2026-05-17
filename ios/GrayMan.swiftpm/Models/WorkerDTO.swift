import Foundation

// MARK: - DTOs (mirror app/schemas/worker.py + vouch.py + auth.py)

struct WorkerDTO: Decodable, Hashable, Sendable {
    let id: String
    let phone: String
    let name: String
    let trade: String
    let bio: String?
    let skillTags: [String]
    let verifiedTagIndices: [Int]
    let city: String?
    let lat: Double?
    let lng: Double?
    let avatarURL: String?
    let reelURL: String?
    let vouchScore: Int
    let isActive: Bool
    // Reel analysis state (only meaningful for self profile, but present on
    // every Worker payload).
    let analysisStatus: String?
    let extractedTrade: String?
    let extractedYears: Int?
    let extractedSkills: [String]?
    let extractedBio: String?
    // Verified badge — flipped true when the worker accepts a reel analysis
    // whose trade_match_score crosses the verification threshold.
    let isVerified: Bool?

    enum CodingKeys: String, CodingKey {
        case id, phone, name, trade, bio
        case skillTags = "skill_tags"
        case verifiedTagIndices = "verified_tag_indices"
        case city, lat, lng
        case avatarURL = "avatar_url"
        case reelURL = "reel_url"
        case vouchScore = "vouch_score"
        case isActive = "is_active"
        case analysisStatus = "analysis_status"
        case extractedTrade = "extracted_trade"
        case extractedYears = "extracted_years"
        case extractedSkills = "extracted_skills"
        case extractedBio = "extracted_bio"
        case isVerified = "is_verified"
    }
}

// MARK: - Interactions

struct InteractionCountsDTO: Decodable, Sendable {
    let likes: Int
    let saves: Int
    let messages: Int
}

struct WorkerActionStateDTO: Decodable, Sendable {
    let hasLiked: Bool
    let hasSaved: Bool
    let hasVouched: Bool
    enum CodingKeys: String, CodingKey {
        case hasLiked = "has_liked"
        case hasSaved = "has_saved"
        case hasVouched = "has_vouched"
    }
}

struct MessageCreateRequest: Encodable {
    let toWorkerID: String
    let body: String
    enum CodingKeys: String, CodingKey {
        case toWorkerID = "to_worker_id"
        case body
    }
}

struct MessageDTO: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let fromWorkerID: String
    let toWorkerID: String
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case fromWorkerID = "from_worker_id"
        case toWorkerID = "to_worker_id"
        case body
        case createdAt = "created_at"
    }
}

// MARK: - Reels

struct ReelUploadURLDTO: Decodable {
    let uploadURL: String
    let key: String
    let publicURL: String
    let contentType: String
    let expiresIn: Int
    enum CodingKeys: String, CodingKey {
        case uploadURL = "upload_url"
        case key
        case publicURL = "public_url"
        case contentType = "content_type"
        case expiresIn = "expires_in"
    }
}

struct ReelFinalizeRequest: Encodable {
    let key: String
}

// MARK: - Multipart upload

struct MultipartInitRequest: Encodable {
    let partCount: Int
    let contentType: String
    enum CodingKeys: String, CodingKey {
        case partCount = "part_count"
        case contentType = "content_type"
    }
}

struct MultipartPartURLDTO: Decodable, Sendable {
    let partNumber: Int
    let url: String
    enum CodingKeys: String, CodingKey {
        case partNumber = "part_number"
        case url
    }
}

struct MultipartInitResponseDTO: Decodable, Sendable {
    let key: String
    let uploadID: String
    let partURLs: [MultipartPartURLDTO]
    let expiresIn: Int
    enum CodingKeys: String, CodingKey {
        case key
        case uploadID = "upload_id"
        case partURLs = "part_urls"
        case expiresIn = "expires_in"
    }
}

struct CompletedPartDTO: Encodable {
    let partNumber: Int
    let etag: String
    enum CodingKeys: String, CodingKey {
        case partNumber = "part_number"
        case etag
    }
}

struct MultipartCompleteRequest: Encodable {
    let key: String
    let uploadID: String
    let parts: [CompletedPartDTO]
    /// On-device SFSpeechRecognizer hypothesis captured while the reel was
    /// recording. The backend reel agent still runs its own Gemini STT
    /// (higher quality for Hinglish); this client transcript is a
    /// resilience hint for when server STT degrades. May be nil/empty.
    let transcript: String?
    enum CodingKeys: String, CodingKey {
        case key
        case uploadID = "upload_id"
        case parts
        case transcript
    }
}

struct MultipartAbortRequest: Encodable {
    let key: String
    let uploadID: String
    enum CodingKeys: String, CodingKey {
        case key
        case uploadID = "upload_id"
    }
}

// MARK: - Voice guide

struct VoiceGuideTokenRequest: Encodable {
    let lang: String   // "en", "hi", "hi-en", "mr", "te", "ta", "kn"
}

struct VoiceGuideTokenResponse: Decodable, Sendable {
    let ephemeralToken: String
    let model: String
    let wsURL: String
    let lang: String
    let voice: String
    enum CodingKeys: String, CodingKey {
        case ephemeralToken = "ephemeral_token"
        case model
        case wsURL = "ws_url"
        case lang, voice
    }
}

struct VoiceGuideTranslateRequest: Encodable {
    let text: String
    let lang: String   // "mr", "te", "ta", "kn"
}

struct VoiceGuideTranslateResponse: Decodable, Sendable {
    let translated: String
    let lang: String
}

// MARK: - Interview

struct InterviewScores: Codable, Sendable {
    let confidence: Int
    let clarity: Int
    let tradeCompetence: Int
    let summary: String
    enum CodingKeys: String, CodingKey {
        case confidence, clarity
        case tradeCompetence = "trade_competence"
        case summary
    }
}

struct ReelVerificationDTO: Decodable, Hashable, Sendable {
    let tradeMatchScore: Int
    let flags: [String]
    enum CodingKeys: String, CodingKey {
        case tradeMatchScore = "trade_match_score"
        case flags
    }
}

struct SkillEvidenceDTO: Decodable, Hashable, Sendable, Identifiable {
    let skill: String
    let evidence: String     // "shown" | "described" | "neither"
    var id: String { skill + evidence }
}

// MARK: - Hires

struct HireDTO: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let requesterID: String
    let workerID: String
    let status: String       // requested | accepted | declined | cancelled | completed
    let message: String?
    let createdAt: Date
    let decidedAt: Date?
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case requesterID = "requester_id"
        case workerID    = "worker_id"
        case status, message
        case createdAt   = "created_at"
        case decidedAt   = "decided_at"
        case completedAt = "completed_at"
    }
}

struct HireCreateRequest: Encodable {
    let workerID: String
    let message: String?
    enum CodingKeys: String, CodingKey {
        case workerID = "worker_id"
        case message
    }
}

// MARK: - Work history

struct WorkHistoryDTO: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let workerID: String
    let role: String
    let client: String?
    let periodLabel: String
    let description: String?
    let position: Int

    enum CodingKeys: String, CodingKey {
        case id
        case workerID = "worker_id"
        case role, client
        case periodLabel = "period_label"
        case description, position
    }
}

struct WorkHistoryCreateRequest: Encodable {
    let role: String
    let client: String?
    let periodLabel: String
    let description: String?
    var position: Int = 0
    enum CodingKeys: String, CodingKey {
        case role, client
        case periodLabel = "period_label"
        case description, position
    }
}

struct WorkHistoryUpdateRequest: Encodable {
    var role: String?
    var client: String?
    var periodLabel: String?
    var description: String?
    var position: Int?
    enum CodingKeys: String, CodingKey {
        case role, client
        case periodLabel = "period_label"
        case description, position
    }
}

// MARK: - Showcase

struct ShowcaseItemDTO: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let workerID: String
    let kind: String                  // "photo" | "video" | "audio" | "time_lapse"
    let title: String
    let description: String?
    let mediaURL: String
    let thumbnailURL: String?
    let durationSeconds: Double?
    let position: Int

    enum CodingKeys: String, CodingKey {
        case id
        case workerID = "worker_id"
        case kind, title, description
        case mediaURL = "media_url"
        case thumbnailURL = "thumbnail_url"
        case durationSeconds = "duration_seconds"
        case position
    }
}

struct ShowcaseUploadURLRequest: Encodable {
    let kind: String
    let contentType: String
    enum CodingKeys: String, CodingKey {
        case kind
        case contentType = "content_type"
    }
}

struct ShowcaseUploadURLResponse: Decodable, Sendable {
    let uploadURL: String
    let key: String
    let publicURL: String
    let contentType: String
    let expiresIn: Int
    enum CodingKeys: String, CodingKey {
        case uploadURL = "upload_url"
        case key
        case publicURL = "public_url"
        case contentType = "content_type"
        case expiresIn = "expires_in"
    }
}

struct ShowcaseCreateRequest: Encodable {
    let kind: String
    let title: String
    let description: String?
    let s3Key: String
    let thumbnailURL: String?
    let durationSeconds: Double?
    var position: Int = 0
    enum CodingKeys: String, CodingKey {
        case kind, title, description
        case s3Key = "s3_key"
        case thumbnailURL = "thumbnail_url"
        case durationSeconds = "duration_seconds"
        case position
    }
}

struct ShowcaseUpdateRequest: Encodable {
    var title: String?
    var description: String?
    var position: Int?
}

// Multipart upload (parallels the reel pipeline).
struct ShowcaseMultipartInitRequest: Encodable {
    let kind: String
    let contentType: String
    let partCount: Int
    enum CodingKeys: String, CodingKey {
        case kind
        case contentType = "content_type"
        case partCount = "part_count"
    }
}

struct ShowcaseMultipartInitResponseDTO: Decodable, Sendable {
    let key: String
    let uploadID: String
    let partURLs: [MultipartPartURLDTO]
    let expiresIn: Int
    enum CodingKeys: String, CodingKey {
        case key
        case uploadID = "upload_id"
        case partURLs = "part_urls"
        case expiresIn = "expires_in"
    }
}

struct ShowcaseMultipartCompleteRequest: Encodable {
    let key: String
    let uploadID: String
    let parts: [CompletedPartDTO]
    enum CodingKeys: String, CodingKey {
        case key
        case uploadID = "upload_id"
        case parts
    }
}

struct ShowcaseMultipartAbortRequest: Encodable {
    let key: String
    let uploadID: String
    enum CodingKeys: String, CodingKey {
        case key
        case uploadID = "upload_id"
    }
}

struct AnalysisStatusDTO: Decodable, Sendable {
    let status: String
    let reelURL: String?
    let playbackURL: String?
    let thumbnailURL: String?
    let durationSeconds: Double?
    let transcript: String?
    let extractedTrade: String?
    let extractedYears: Int?
    let extractedSkills: [String]
    let extractedBio: String?
    let reelVerification: ReelVerificationDTO?
    let reelSkillEvidence: [SkillEvidenceDTO]
    let error: String?

    enum CodingKeys: String, CodingKey {
        case status
        case reelURL = "reel_url"
        case playbackURL = "playback_url"
        case thumbnailURL = "thumbnail_url"
        case durationSeconds = "duration_seconds"
        case transcript
        case extractedTrade = "extracted_trade"
        case extractedYears = "extracted_years"
        case extractedSkills = "extracted_skills"
        case extractedBio = "extracted_bio"
        case reelVerification = "reel_verification"
        case reelSkillEvidence = "reel_skill_evidence"
        case error
    }
}

// MARK: - Notifications

struct NotificationDTO: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let kind: String
    let payload: NotificationPayload
    let status: String           // unread | read | accepted | rejected
    let createdAt: Date
    let readAt: Date?
    let decidedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, kind, payload, status
        case createdAt = "created_at"
        case readAt = "read_at"
        case decidedAt = "decided_at"
    }
}

/// Notifications are kind-tagged with an arbitrary JSON payload. We currently
/// only know about ``reel_analysis_ready`` so we decode that explicitly and
/// stash any others as a raw dictionary for forward-compat.
struct NotificationPayload: Decodable, Hashable, Sendable {
    let reelAnalysis: ReelAnalysisProposalDTO?
    let reelURL: String?

    enum CodingKeys: String, CodingKey {
        case extracted, reelURL = "reel_url"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.reelAnalysis = try c.decodeIfPresent(ReelAnalysisProposalDTO.self, forKey: .extracted)
        self.reelURL = try c.decodeIfPresent(String.self, forKey: .reelURL)
    }
}

struct ReelAnalysisProposalDTO: Decodable, Hashable, Sendable {
    let trade: String?
    let years: Int?
    let skills: [String]
    let bio: String?
    let verification: ReelVerificationDTO?
    let skillEvidence: [SkillEvidenceDTO]

    enum CodingKeys: String, CodingKey {
        case trade, years, skills, bio, verification
        case skillEvidence = "skill_evidence"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.trade = try c.decodeIfPresent(String.self, forKey: .trade)
        self.years = try c.decodeIfPresent(Int.self, forKey: .years)
        self.skills = (try? c.decode([String].self, forKey: .skills)) ?? []
        self.bio = try c.decodeIfPresent(String.self, forKey: .bio)
        self.verification = try c.decodeIfPresent(ReelVerificationDTO.self, forKey: .verification)
        self.skillEvidence = (try? c.decode([SkillEvidenceDTO].self, forKey: .skillEvidence)) ?? []
    }
}

struct NotificationListResponseDTO: Decodable, Sendable {
    let notifications: [NotificationDTO]
    let unreadCount: Int
    enum CodingKeys: String, CodingKey {
        case notifications
        case unreadCount = "unread_count"
    }
}

struct NotificationAcceptResponseDTO: Decodable, Sendable {
    let notificationID: String
    let isVerified: Bool
    let appliedSkills: [String]
    let appliedTrade: String?
    let appliedBio: String?
    enum CodingKeys: String, CodingKey {
        case notificationID = "notification_id"
        case isVerified = "is_verified"
        case appliedSkills = "applied_skills"
        case appliedTrade = "applied_trade"
        case appliedBio = "applied_bio"
    }
}

struct NotificationDecisionDTO: Decodable, Sendable {
    let notificationID: String
    let status: String
    enum CodingKeys: String, CodingKey {
        case notificationID = "notification_id"
        case status
    }
}

struct WorkerUpdateRequest: Encodable {
    var name: String?
    var trade: String?
    var bio: String?
    var skillTags: [String]?
    var verifiedTagIndices: [Int]?
    var city: String?
    var lat: Double?
    var lng: Double?
    var avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case name, trade, bio
        case skillTags = "skill_tags"
        case verifiedTagIndices = "verified_tag_indices"
        case city, lat, lng
        case avatarURL = "avatar_url"
    }
}

struct VouchCreateRequest: Encodable {
    let toWorkerID: String
    let skillIndices: [Int]
    let voiceNoteURL: String?

    enum CodingKeys: String, CodingKey {
        case toWorkerID = "to_worker_id"
        case skillIndices = "skill_indices"
        case voiceNoteURL = "voice_note_url"
    }
}

struct VouchDTO: Decodable, Hashable, Sendable {
    let id: String
    let fromWorkerID: String
    let toWorkerID: String
    let skillIndices: [Int]
    let voiceNoteURL: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case fromWorkerID = "from_worker_id"
        case toWorkerID = "to_worker_id"
        case skillIndices = "skill_indices"
        case voiceNoteURL = "voice_note_url"
        case createdAt = "created_at"
    }
}

// MARK: - Posts (Home feed)

struct PostAuthorDTO: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let trade: String
    let avatarURL: String?
    let isVerified: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, trade
        case avatarURL = "avatar_url"
        case isVerified = "is_verified"
    }
}

struct PostDTO: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let author: PostAuthorDTO
    let body: String
    let imageURL: String?
    let lat: Double?
    let lng: Double?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, author, body, lat, lng
        case imageURL = "image_url"
        case createdAt = "created_at"
    }
}

struct PostCreateRequest: Encodable {
    let body: String
    let imageURL: String?
    let lat: Double?
    let lng: Double?

    enum CodingKeys: String, CodingKey {
        case body, lat, lng
        case imageURL = "image_url"
    }
}

struct PresignedUploadDTO: Decodable, Sendable {
    let uploadURL: String
    let key: String
    let publicURL: String
    let contentType: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case uploadURL = "upload_url"
        case key
        case publicURL = "public_url"
        case contentType = "content_type"
        case expiresIn = "expires_in"
    }
}

struct OTPSendRequest: Encodable {
    let phone: String
}

struct OTPSendResponse: Decodable {
    let message: String
    let expiresIn: Int
    enum CodingKeys: String, CodingKey {
        case message
        case expiresIn = "expires_in"
    }
}

struct OTPVerifyRequest: Encodable {
    let phone: String
    let otp: String
}

struct TokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let workerID: String
    let isNewWorker: Bool
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case workerID = "worker_id"
        case isNewWorker = "is_new_worker"
    }
}

// MARK: - WorkerDTO → Worker mapping
//
// The backend stores the canonical fields; the UI needs a few presentation-
// only extras (emoji, gradient hexes, initials, formatted location/distance).
// We derive those from the trade and the user's reference location so the
// view layer stays unchanged.

extension Worker {
    init(dto: WorkerDTO, userLat: Double, userLng: Double) {
        let style = TradeStyle.forTrade(dto.trade)
        let initials: String = {
            let chars = dto.name.split(separator: " ").compactMap(\.first).map(String.init)
            return chars.prefix(2).joined().uppercased()
        }()
        let distance: Double = {
            guard let lat = dto.lat, let lng = dto.lng else { return 0 }
            return haversineKm(lat1: userLat, lng1: userLng, lat2: lat, lng2: lng)
        }()
        let cityLabel = dto.city ?? "Mumbai"
        let locationString = (dto.lat != nil && dto.lng != nil)
            ? String(format: "%@ · %.1f km", cityLabel, distance)
            : cityLabel

        // The backend doesn't store jobs-done / rating yet — derive plausible
        // values from vouch_score so the UI looks alive. Replace these with
        // real fields once they're added to the schema.
        let derivedJobs = max(12, dto.vouchScore * 6)
        let derivedRating: String = {
            let r = 4.0 + (Double(dto.vouchScore) / 100.0) * 1.0
            return String(format: "%.1f", min(5.0, r))
        }()

        self.init(
            id: dto.id,
            initials: initials,
            name: dto.name,
            trade: dto.trade,
            phone: dto.phone,
            bio: dto.bio,
            location: locationString,
            distanceKm: distance,
            vouched: dto.vouchScore,
            vouchScore: dto.vouchScore,
            jobs: derivedJobs,
            rating: derivedRating,
            tags: dto.skillTags,
            verifiedTagIndices: Set(dto.verifiedTagIndices),
            emoji: style.emoji,
            gradientStartHex: style.startHex,
            gradientEndHex: style.endHex,
            isVerified: dto.isVerified ?? false,
            avatarURL: dto.avatarURL
        )
    }
}

// MARK: - Trade → visual style table

private struct TradeStyle {
    let emoji: String
    let startHex: String
    let endHex: String

    static func forTrade(_ trade: String) -> TradeStyle {
        let lower = trade.lowercased()
        if lower.contains("electric")  { return .init(emoji: "⚡", startHex: "#0c1829", endHex: "#1a3355") }
        if lower.contains("plumb")     { return .init(emoji: "🔧", startHex: "#081420", endHex: "#102840") }
        if lower.contains("hvac") || lower.contains("ac ")
                                       { return .init(emoji: "❄️", startHex: "#061a0e", endHex: "#0c3018") }
        if lower.contains("interior") || lower.contains("decorator")
                                       { return .init(emoji: "🎨", startHex: "#1e0f05", endHex: "#3d2210") }
        if lower.contains("weld")      { return .init(emoji: "🔥", startHex: "#1a0800", endHex: "#361400") }
        if lower.contains("nurse")     { return .init(emoji: "🏥", startHex: "#0e0718", endHex: "#1c1030") }
        if lower.contains("carpenter") { return .init(emoji: "🪚", startHex: "#1a0f00", endHex: "#33200a") }
        if lower.contains("paint")     { return .init(emoji: "🎨", startHex: "#0a0a1e", endHex: "#16163a") }
        if lower.contains("mason")     { return .init(emoji: "🧱", startHex: "#1f1208", endHex: "#3a2412") }
        if lower.contains("cook")      { return .init(emoji: "🍳", startHex: "#1c0a00", endHex: "#3a1c08") }
        if lower.contains("driver")    { return .init(emoji: "🚗", startHex: "#0a0a0a", endHex: "#1c1c1c") }
        if lower.contains("guard") || lower.contains("security")
                                       { return .init(emoji: "🛡️", startHex: "#0a0a14", endHex: "#1c1c30") }
        if lower.contains("tailor")    { return .init(emoji: "🧵", startHex: "#160a14", endHex: "#2e1830") }
        if lower.contains("garden")    { return .init(emoji: "🌿", startHex: "#0a1c0a", endHex: "#163018") }
        if lower.contains("appliance") || lower.contains("repair")
                                       { return .init(emoji: "🔌", startHex: "#0a141a", endHex: "#162a36") }
        if lower.contains("mechanic")  { return .init(emoji: "🔩", startHex: "#0a0a0a", endHex: "#262626") }
        return .init(emoji: "🛠️", startHex: "#161616", endHex: "#2d2d2d")
    }
}

// MARK: - Haversine

func haversineKm(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
    let R = 6371.0
    let phi1 = lat1 * .pi / 180
    let phi2 = lat2 * .pi / 180
    let dphi = (lat2 - lat1) * .pi / 180
    let dlam = (lng2 - lng1) * .pi / 180
    let a = sin(dphi / 2) * sin(dphi / 2)
          + cos(phi1) * cos(phi2) * sin(dlam / 2) * sin(dlam / 2)
    return R * 2 * atan2(sqrt(a), sqrt(1 - a))
}
