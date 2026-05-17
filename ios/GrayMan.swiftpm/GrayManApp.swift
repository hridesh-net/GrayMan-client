import SwiftUI

// MARK: - Routing
//
// Mirrors the React App() screen-state machine. Each screen calls back
// to advance / retreat; the App owns the canonical state.

enum Screen: Equatable {
    case onboarding   // S1 — splash + Get Started / Sign In
    case phoneAuth    // S2 — phone + OTP
    case nameEntry    // SName — capture user's display name
    case chooseRole   // SChoose — Professional or Explore
    case recordReel   // SRecord — 30s intro video
    case explore      // SExplore — swipeable nearby-worker feed
    case workerProfile // S3 in "view other worker" mode
    case profile      // S3 — own dashboard with glass tab bar
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
        // If we already have a JWT in the Keychain, skip the auth flow and
        // drop the user straight into their profile. Otherwise start at the
        // splash screen.
        let hasToken = TokenStore.shared.token != nil
        _screen = State(initialValue: hasToken ? .profile : .onboarding)
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
                    screen = .chooseRole
                    Task { try? await WorkerService.shared.updateSelf(WorkerUpdateRequest(name: name)) }
                }
            )

        case .chooseRole:
            ChooseRoleView(
                name: userName.split(separator: " ").first.map(String.init) ?? userName,
                goBack: { screen = .nameEntry },
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
                goDone: { _ in screen = .profile }
            )

        case .explore:
            ExploreView(
                onBack: { screen = previousScreen },
                onViewProfile: { worker in
                    selectedWorker = worker
                    screen = .workerProfile
                },
                onGoProfile: { screen = .profile }
            )

        case .workerProfile:
            ProfileView(
                worker: selectedWorker,
                onBack: { screen = .explore }
            )

        case .profile:
            ProfileView(
                userName: userName.isEmpty ? "Ramesh Kumar" : userName,
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
                }
            )
        }
    }

    private func goExplore(from origin: Screen) {
        previousScreen = origin
        screen = .explore
    }
}
