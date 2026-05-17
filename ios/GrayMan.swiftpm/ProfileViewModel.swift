import Foundation

@Observable @MainActor
final class ProfileViewModel {
    enum Mode: Equatable {
        case selfProfile
        case otherWorker(id: String)
    }

    enum LoadState: Equatable {
        case idle, loading, loaded, failed(String)
    }

    let mode: Mode
    private(set) var state: LoadState = .idle
    private(set) var worker: Worker?
    private(set) var receivedVouchCount: Int = 0
    private(set) var lastError: String?
    private(set) var analysis: AnalysisStatusDTO?
    private(set) var unreadNotifications: Int = 0
    private(set) var hasPendingReelReview: Bool = false
    /// Server-sourced work history. If the worker has none, the view falls
    /// back to the trade-keyed `WorkHistorySamples` so the section isn't blank.
    private(set) var workHistory: [WorkHistoryDTO] = []
    /// Has the viewer ever completed a hire of this worker? Used to gate
    /// the vouch action (backend will refuse with 403 otherwise).
    private(set) var hasCompletedHire: Bool = false
    /// In-flight hire state for this worker, from the viewer's perspective.
    /// `requested` / `accepted` / `completed` / `cancelled` / `declined` / nil.
    private(set) var activeHireStatus: String?

    private let service: WorkerService
    private var analysisPollTask: Task<Void, Never>?

    init(mode: Mode, service: WorkerService = .shared, seed: Worker? = nil) {
        self.mode = mode
        self.service = service
        self.worker = seed
        if let seed { self.receivedVouchCount = seed.vouchScore }
    }

    // Note: not cancelling analysisPollTask in deinit (it's main-actor-only).
    // The task captures `weak self`, so it exits cleanly on the next tick
    // after the VM is deallocated.

    func load() async {
        state = .loading
        do {
            switch mode {
            case .selfProfile:
                worker = try await service.fetchSelf()
            case .otherWorker(let id):
                worker = try await service.fetchWorker(id: id)
            }
            if let workerID = worker?.id {
                if let received = try? await service.fetchReceivedVouches(for: workerID) {
                    receivedVouchCount = received.count
                }
                // Work history is silent on failure — the section just falls
                // back to the trade-keyed sample table.
                if let history = try? await service.fetchWorkHistory(workerID: workerID) {
                    workHistory = history
                }
                // Hire status only matters when looking at someone else.
                if case .otherWorker = mode {
                    if let outgoing = try? await service.fetchHires(direction: "outgoing") {
                        let mine = outgoing.filter { $0.workerID == workerID }
                        hasCompletedHire = mine.contains { $0.status == "completed" }
                        // Pick the most recent "live" record (latest non-terminal
                        // status surfaces in the UI for the action button).
                        activeHireStatus = mine.first?.status
                    }
                }
            }
            state = .loaded
            if mode == .selfProfile { await refreshAnalysis() }
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            lastError = msg
            state = .failed(msg)
        }
    }

    func refreshAnalysis() async {
        guard mode == .selfProfile else { return }
        do {
            analysis = try await service.fetchAnalysisStatus()
            if analysis?.status == "processing" || analysis?.status == "pending" {
                startPollingAnalysis()
            }
        } catch {
            // Silent — the banner just won't show.
        }
        await refreshNotifications()
    }

    /// Pull unread / pending review counts so the bell badge stays current.
    /// Cheap call — backend returns counts only, not paginated bodies.
    func refreshNotifications() async {
        guard mode == .selfProfile else { return }
        do {
            let resp = try await service.fetchNotifications(onlyUndecided: false, limit: 50)
            unreadNotifications = resp.unreadCount
            hasPendingReelReview = resp.notifications.contains { n in
                n.kind == "reel_analysis_ready" && (n.status == "unread" || n.status == "read")
            }
        } catch {
            // Silent — the bell just won't show a badge.
        }
    }

    private func startPollingAnalysis() {
        analysisPollTask?.cancel()
        analysisPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, let self else { return }
                guard let next = try? await self.service.fetchAnalysisStatus() else { continue }
                self.analysis = next
                if next.status == "done" {
                    // Don't reload the worker — extracted_* is a *proposal* now,
                    // not applied to the profile. The bell will surface a
                    // reel_analysis_ready notification to review and accept.
                    await self.refreshNotifications()
                    return
                }
                if next.status == "failed" { return }
            }
        }
    }

    /// Create a hire request against the currently-loaded worker. Returns
    /// the new HireDTO so the caller can show a confirmation toast.
    @discardableResult
    func createHire(message: String? = nil) async throws -> HireDTO {
        guard let workerID = worker?.id else {
            throw APIError.unknown(NSError(domain: "ProfileVM", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Worker not loaded"]))
        }
        let dto = try await service.createHire(workerID: workerID, message: message)
        activeHireStatus = dto.status
        return dto
    }

    /// Create a new work-history entry, then refresh the list so the
    /// timeline on the profile shows it immediately. Throws so the caller
    /// can surface a validation error in the sheet UI.
    func addWorkHistory(_ body: WorkHistoryCreateRequest) async throws {
        _ = try await service.createWorkHistory(body)
        if let workerID = worker?.id,
           let updated = try? await service.fetchWorkHistory(workerID: workerID) {
            workHistory = updated
        }
    }

    func updateName(_ name: String) async {
        do {
            worker = try await service.updateSelf(WorkerUpdateRequest(name: name))
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func update(_ update: WorkerUpdateRequest) async {
        do {
            worker = try await service.updateSelf(update)
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
