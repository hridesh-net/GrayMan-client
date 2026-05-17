import Foundation

// MARK: - Home view model
//
// Owns the data the Home screen renders:
//   • Stats card: jobs done (count of completed hires), experience
//     years (derived from earliest work_history start year), rating
//     (vouch-derived, kept for now), vouches received.
//   • Recent Work feed (paginated /posts/feed).
//
// `load()` is the first-render path — fans out the stats fetches and
// the first feed page in parallel.

@Observable @MainActor
final class HomeViewModel {

    enum FeedState: Equatable {
        case idle, loading, loaded, failed(String)
    }

    // Profile + derived stats
    private(set) var worker: Worker?
    private(set) var jobsDone: Int = 0
    private(set) var vouchesReceived: Int = 0
    private(set) var experienceYears: Int = 0
    /// Trade-keyed rating still derived from vouch_score (no real
    /// rating signal on the backend yet — the user explicitly opted to
    /// keep this for now).
    private(set) var rating: String = "0.0"

    // Feed
    private(set) var posts: [PostDTO] = []
    private(set) var feedState: FeedState = .idle
    private(set) var canLoadMore: Bool = true

    private let service: WorkerService
    private let pageLimit = 20
    private var nextPage = 1

    init(service: WorkerService = .shared) {
        self.service = service
    }

    /// First-render entry point. Loads the self profile, the
    /// supporting counts, and the first page of the feed concurrently.
    func load() async {
        feedState = .loading

        // Self profile is the only call others depend on (work history
        // is keyed by worker ID). Everything else fans out.
        async let selfFetch: Worker = service.fetchSelf()
        async let feedFetch: [PostDTO] = service.fetchFeed(
            lat: LocationService.shared.lastKnown?.lat,
            lng: LocationService.shared.lastKnown?.lng,
            page: 1, limit: pageLimit,
        )
        async let incomingHiresTask: [HireDTO]? = (try? await service.fetchHires(direction: "incoming"))

        do {
            let me = try await selfFetch
            self.worker = me
            self.rating = me.rating
            self.vouchesReceived = me.vouchScore

            // History → experience years
            if let history = try? await service.fetchWorkHistory(workerID: me.id) {
                experienceYears = Self.experienceYears(fromHistory: history)
            }

            // Vouches: prefer the actual count from /vouches/received over the
            // composite vouch_score, which is the trust ring (0-100) not a
            // raw endorsement count.
            if let received = try? await service.fetchReceivedVouches(for: me.id) {
                vouchesReceived = received.count
            }

            // Jobs done = completed hires (incoming, where I'm the worker)
            if let incoming = await incomingHiresTask {
                jobsDone = incoming.filter { $0.status == "completed" }.count
            }
        } catch {
            // Profile fetch failed — leave stats at zero, surface the
            // error via the feed state since the feed loaded too.
        }

        do {
            let firstPage = try await feedFetch
            posts = firstPage
            canLoadMore = firstPage.count == pageLimit
            nextPage = 2
            feedState = .loaded
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            feedState = .failed(msg)
        }
    }

    func loadMoreIfNeeded(currentPostID: String) async {
        // Trigger pagination when the user is within a few cards of the end.
        guard canLoadMore, feedState == .loaded else { return }
        guard let idx = posts.firstIndex(where: { $0.id == currentPostID }) else { return }
        guard idx >= posts.count - 5 else { return }

        do {
            let next = try await service.fetchFeed(
                lat: LocationService.shared.lastKnown?.lat,
                lng: LocationService.shared.lastKnown?.lng,
                page: nextPage, limit: pageLimit,
            )
            // Dedupe by id in case of overlap (server-side ordering can drift
            // when a post arrives mid-pagination).
            let existingIDs = Set(posts.map(\.id))
            let fresh = next.filter { !existingIDs.contains($0.id) }
            posts.append(contentsOf: fresh)
            canLoadMore = next.count == pageLimit
            nextPage += 1
        } catch {
            // Stop paginating on error so we don't hammer a flaky link.
            canLoadMore = false
        }
    }

    /// Insert a freshly-created post at the top of the feed so the
    /// user sees it immediately. Called by the create-post sheet on
    /// successful POST.
    func prepend(post: PostDTO) {
        posts.insert(post, at: 0)
    }

    // MARK: - Derive experience years

    /// Total years derived purely from user-entered work history. Two
    /// strategies, in priority order:
    ///   1. If `startDate` is set on any entry (YYYY-MM-DD from the
    ///      Month/Year picker), use it directly. More accurate than
    ///      parsing free text.
    ///   2. Fall back to scanning `periodLabel` for the earliest
    ///      4-digit year — handles legacy entries written before the
    ///      pickers existed.
    ///
    /// Returns 0 when the worker has added no history. The reel
    /// analysis NEVER contributes to this number — experience is an
    /// explicit user statement, not an AI inference.
    static func experienceYears(fromHistory history: [WorkHistoryDTO]) -> Int {
        var earliest = Int.max

        for entry in history {
            // Strategy 1 — structured start date.
            if let raw = entry.startDate, raw.count >= 4,
               let yr = Int(raw.prefix(4)),
               yr >= 1970, yr <= 2100, yr < earliest {
                earliest = yr
                continue
            }
            // Strategy 2 — parse the label.
            for token in entry.periodLabel.split(whereSeparator: { !$0.isNumber }) {
                if token.count == 4, let yr = Int(token),
                   yr >= 1970, yr <= 2100, yr < earliest {
                    earliest = yr
                }
            }
        }

        guard earliest != .max else { return 0 }
        let thisYear = Calendar.current.component(.year, from: Date())
        return max(0, thisYear - earliest)
    }
}
