import SwiftUI

// MARK: - Routing
//
// Mirrors the React App() screen-state machine. Each screen calls back
// to advance / retreat; the App owns the canonical state.

enum Screen: Equatable {
    case onboarding       // S1 — splash + Get Started / Sign In
    case phoneAuth        // S2 — phone + OTP
    case nameEntry        // SName — capture user's display name
    case avatarOnboarding // SAvatar — optional profile-photo picker
    case chooseRole       // SChoose — Professional or Explore
    case recordReel       // SRecord — 30s intro video
    case explore          // SExplore — swipeable nearby-worker feed
    case workerProfile    // S3 in "view other worker" mode
    case home             // SHome — stats card + nearby posts feed (landing)
    case profile          // S3 — own dashboard with glass tab bar
}

@main
struct GrayManApp: App {
    @State private var theme = AppTheme()
    @State private var screen: Screen
    @State private var userName: String = ""
    @State private var selectedWorker: Worker? = nil
    @State private var previousScreen: Screen = .chooseRole   // for Explore back-nav
    @State private var reelOrigin: Screen = .chooseRole       // for RecordReel back-nav (chooseRole vs profile re-shoot)

    // Composition root: swap these for real implementations as the backend lands.
    private let phoneAuthRepository: PhoneAuthRepository = APIPhoneAuthRepository()
    private let recordingService: RecordingService = AVRecordingService()

    init() {
        // Raise URLCache.shared above the iOS default (≈4 MB memory /
        // 20 MB disk) so AsyncImage's repeated fetches in the Home feed
        // hit cache after the first paint. Saves repeated 100-300 KB
        // PNG/JPEG fetches on Tier-3 networks, which is the difference
        // between "feels native" and "perpetually loading".
        URLCache.shared = URLCache(
            memoryCapacity: 32 * 1024 * 1024,    // 32 MB
            diskCapacity:   256 * 1024 * 1024,   // 256 MB
            directory: nil,
        )

        // If we already have a JWT in the Keychain, skip the auth flow and
        // drop the user straight into the Home screen. Otherwise start at
        // the splash screen.
        let hasToken = TokenStore.shared.token != nil
        _screen = State(initialValue: hasToken ? .home : .onboarding)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                screenView
                    .transition(.opacity)

                #if DEBUG
                // Floating colour picker is a design-tool overlay; ship-mode hides it.
                ColorPanel()
                    .allowsHitTesting(true)
                #endif
            }
            .environment(theme)
            // Force light mode app-wide so `.glassEffect()` is consistent
            // regardless of the device's system appearance setting.
            .preferredColorScheme(.light)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .animation(.easeInOut(duration: 0.25), value: screen)
        }
    }

    @ViewBuilder
    private var screenView: some View {
        switch screen {
        case .onboarding:
            OnboardingView(
                goNext: { screen = .phoneAuth }
            )

        case .phoneAuth:
            PhoneAuthView(
                model: PhoneAuthViewModel(repository: phoneAuthRepository),
                goBack: { screen = .onboarding },
                goNext: { screen = .nameEntry }
            )

        case .nameEntry:
            NameEntryView(
                goBack: { screen = .phoneAuth },
                goNext: { name in
                    userName = name
                    screen = .avatarOnboarding
                    Task { try? await WorkerService.shared.updateSelf(WorkerUpdateRequest(name: name)) }
                }
            )

        case .avatarOnboarding:
            AvatarPickerView(
                name: userName,
                goBack: { screen = .nameEntry },
                goNext: { screen = .chooseRole }
            )

        case .chooseRole:
            ChooseRoleView(
                name: userName.split(separator: " ").first.map(String.init) ?? userName,
                goBack: { screen = .avatarOnboarding },
                goProfessional: {
                    reelOrigin = .chooseRole
                    screen = .recordReel
                },
                goExplore: { goExplore(from: .chooseRole) }
            )

        case .recordReel:
            RecordReelView(
                model: RecordReelViewModel(service: recordingService),
                goBack: { screen = reelOrigin },
                goDone: { _ in screen = .home }
            )

        case .explore:
            ReelFeedView(
                onBack: { screen = previousScreen },
                onViewProfile: { worker in
                    selectedWorker = worker
                    screen = .workerProfile
                },
                onGoProfile: { screen = .profile },
                onGoHome: { screen = .home },
                // Settings lives inside ProfileView — route through
                // Profile so the user lands somewhere meaningful.
                onGoSettings: { screen = .profile }
            )

        case .workerProfile:
            ProfileView(
                worker: selectedWorker,
                onBack: { screen = .explore }
            )

        case .home:
            HomeView(
                userName: userName,
                onProfile: { screen = .profile },
                onExplore: { goExplore(from: .home) },
                onSettings: { screen = .profile },  // Settings lives inside ProfileView for now
                onViewWorker: { worker in
                    selectedWorker = worker
                    screen = .workerProfile
                }
            )

        case .profile:
            ProfileView(
                // Pass through whatever name we have (may be empty for a
                // returning user with a stored token). ProfileView shows
                // a redacted skeleton until the backend profile loads.
                userName: userName,
                onExplore: { goExplore(from: .profile) },
                onSignOut: {
                    userName = ""
                    selectedWorker = nil
                    previousScreen = .chooseRole
                    screen = .onboarding
                },
                onRecordReel: {
                    reelOrigin = .profile
                    screen = .recordReel
                },
                onHome: { screen = .home }
            )
        }
    }

    private func goExplore(from origin: Screen) {
        previousScreen = origin
        screen = .explore
    }
}
