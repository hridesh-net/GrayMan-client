import Foundation

@Observable @MainActor
final class ExploreViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    struct InteractionState: Equatable {
        var counts: (likes: Int, saves: Int, messages: Int) = (0, 0, 0)
        var hasLiked: Bool = false
        var hasSaved: Bool = false
        var hasVouched: Bool = false

        static func == (lhs: InteractionState, rhs: InteractionState) -> Bool {
            lhs.counts.likes == rhs.counts.likes && lhs.counts.saves == rhs.counts.saves
                && lhs.counts.messages == rhs.counts.messages
                && lhs.hasLiked == rhs.hasLiked && lhs.hasSaved == rhs.hasSaved
                && lhs.hasVouched == rhs.hasVouched
        }
    }

    private(set) var workers: [Worker] = []
    private(set) var state: LoadState = .idle
    private(set) var interactions: [String: InteractionState] = [:]
    /// True once `/explore` returns fewer than `pageLimit` rows — the
    /// feed stops fetching new pages and switches to circular wrap mode
    /// instead (appending copies of `seed` so the user can keep
    /// scrolling forever).
    private(set) var reachedEnd: Bool = false

    var radius: Int = 50 {
        didSet { if oldValue != radius { reloadDebounced() } }
    }

    var selectedCategory: String = "All" {
        didSet { if oldValue != selectedCategory { reloadDebounced() } }
    }

    private let service: WorkerService
    private var activeTask: Task<Void, Never>?
    private var nextPage: Int = 1
    private let pageLimit: Int = 20
    /// The canonical list of unique workers returned by `/explore`. After
    /// `reachedEnd` flips true, this is what we repeat-append into
    /// `workers` to create the circular feed.
    private var seed: [Worker] = []
    /// Cap on circular growth so the in-memory list can't expand
    /// unboundedly on heavy scrollers. With pageLimit=20 and 5 loops
    /// you get at most ~100 entries per session before re-fetch.
    private let maxLoops: Int = 8

    init(service: WorkerService = .shared) {
        self.service = service
    }

    func onAppear() async {
        guard workers.isEmpty else { return }
        await reload()
    }

    private func reloadDebounced() {
        activeTask?.cancel()
        activeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            await self?.reload()
        }
    }

    func reload() async {
        state = .loading
        nextPage = 1
        reachedEnd = false
        seed = []
        do {
            let trade = (selectedCategory == "All") ? nil : selectedCategory
            let result = try await service.fetchExplore(
                trade: trade,
                radiusKm: Double(radius),
                page: nextPage,
                limit: pageLimit,
            )
            workers = result
            seed = result
            reachedEnd = result.count < pageLimit
            nextPage += 1
            state = .loaded
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// Paginate when the user is within `loadAheadOf` items of the end.
    /// Two phases:
    ///   1. Before `/explore` is exhausted, fetch the next page.
    ///   2. After exhaustion, append a fresh copy of `seed` so the feed
    ///      loops — capped at `maxLoops` so the in-memory list can't
    ///      grow without bound.
    /// No-op when a request is in flight or the index is outside the
    /// current list.
    func loadMoreIfNeeded(currentIndex idx: Int, loadAheadOf: Int = 5) async {
        guard workers.indices.contains(idx) else { return }
        guard idx >= workers.count - loadAheadOf else { return }

        if !reachedEnd {
            guard state != .loading else { return }
            let trade = (selectedCategory == "All") ? nil : selectedCategory
            do {
                let next = try await service.fetchExplore(
                    trade: trade,
                    radiusKm: Double(radius),
                    page: nextPage,
                    limit: pageLimit,
                )
                // Dedupe — the backend doesn't strictly guarantee non-overlap
                // when new workers register mid-pagination.
                let existing = Set(seed.map(\.id))
                let fresh = next.filter { !existing.contains($0.id) }
                workers.append(contentsOf: fresh)
                seed.append(contentsOf: fresh)
                reachedEnd = next.count < pageLimit
                nextPage += 1
            } catch {
                // Stop paginating on error so we don't hammer a flaky link;
                // pull-to-refresh will retry. Switch to circular-wrap so
                // the user still has something to scroll through.
                reachedEnd = true
            }
            return
        }

        // Circular wrap. Append another copy of the seed unless we'd
        // exceed the loop cap.
        guard !seed.isEmpty else { return }
        let nextSize = workers.count + seed.count
        guard nextSize <= seed.count * maxLoops else { return }
        workers.append(contentsOf: seed)
    }

    // MARK: Per-worker interaction state

    func loadInteractions(for workerID: String) async {
        async let counts = try? service.fetchInteractionCounts(workerID: workerID)
        async let state = try? service.fetchMyActionState(workerID: workerID)
        let (c, s) = await (counts, state)
        var snapshot = interactions[workerID] ?? InteractionState()
        if let c { snapshot.counts = (c.likes, c.saves, c.messages) }
        if let s {
            snapshot.hasLiked = s.hasLiked
            snapshot.hasSaved = s.hasSaved
            snapshot.hasVouched = s.hasVouched
        }
        interactions[workerID] = snapshot
    }

    /// Optimistically flip the heart, send the API call, revert on failure.
    func toggleLike(workerID: String) async {
        var snap = interactions[workerID] ?? InteractionState()
        let wasLiked = snap.hasLiked
        snap.hasLiked.toggle()
        snap.counts.likes += wasLiked ? -1 : 1
        interactions[workerID] = snap
        do {
            if wasLiked {
                try await service.unlike(workerID: workerID)
            } else {
                try await service.like(workerID: workerID)
            }
        } catch {
            // Revert.
            var revert = interactions[workerID] ?? InteractionState()
            revert.hasLiked = wasLiked
            revert.counts.likes += wasLiked ? 1 : -1
            interactions[workerID] = revert
        }
    }

    func toggleSave(workerID: String) async {
        var snap = interactions[workerID] ?? InteractionState()
        let wasSaved = snap.hasSaved
        snap.hasSaved.toggle()
        snap.counts.saves += wasSaved ? -1 : 1
        interactions[workerID] = snap
        do {
            if wasSaved {
                try await service.unsave(workerID: workerID)
            } else {
                try await service.save(workerID: workerID)
            }
        } catch {
            var revert = interactions[workerID] ?? InteractionState()
            revert.hasSaved = wasSaved
            revert.counts.saves += wasSaved ? 1 : -1
            interactions[workerID] = revert
        }
    }

    func sendMessage(to workerID: String, body: String) async throws {
        try await service.sendMessage(toWorkerID: workerID, body: body)
        var snap = interactions[workerID] ?? InteractionState()
        snap.counts.messages += 1
        interactions[workerID] = snap
    }
}
