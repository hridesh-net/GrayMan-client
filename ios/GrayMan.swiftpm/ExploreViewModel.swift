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

    var radius: Int = 50 {
        didSet { if oldValue != radius { reloadDebounced() } }
    }

    var selectedCategory: String = "All" {
        didSet { if oldValue != selectedCategory { reloadDebounced() } }
    }

    private let service: WorkerService
    private var activeTask: Task<Void, Never>?

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
        do {
            let trade = (selectedCategory == "All") ? nil : selectedCategory
            let result = try await service.fetchExplore(
                trade: trade,
                radiusKm: Double(radius)
            )
            workers = result
            state = .loaded
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
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
