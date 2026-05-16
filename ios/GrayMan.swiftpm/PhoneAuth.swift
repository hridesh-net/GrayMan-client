import Foundation

// MARK: - Errors

enum PhoneAuthError: LocalizedError, Equatable {
    case invalidPhone
    case sendFailed(underlying: String)
    case invalidCode
    case verifyFailed(underlying: String)

    var errorDescription: String? {
        switch self {
        case .invalidPhone:           return "Please enter a valid phone number."
        case .sendFailed(let why):    return "Couldn't send the code: \(why)"
        case .invalidCode:            return "That code doesn't match. Try again."
        case .verifyFailed(let why):  return "Verification failed: \(why)"
        }
    }
}

// MARK: - Domain types

struct PhoneNumber: Equatable, Sendable {
    let countryCode: String    // "+91"
    let national: String       // "9876543210"

    var e164: String { countryCode + national }
    var isValid: Bool { national.count >= 10 }
}

// MARK: - Repository

protocol PhoneAuthRepository: Sendable {
    func sendCode(to phone: PhoneNumber) async throws
    func verify(code: String, for phone: PhoneNumber) async throws
}

// Mock used until the SMS / WhatsApp backend is wired up. Demo code is "1234".
final class MockPhoneAuthRepository: PhoneAuthRepository {
    func sendCode(to phone: PhoneNumber) async throws {
        try await Task.sleep(for: .milliseconds(600))
        guard phone.isValid else { throw PhoneAuthError.invalidPhone }
    }

    func verify(code: String, for phone: PhoneNumber) async throws {
        try await Task.sleep(for: .milliseconds(600))
        guard code == "1234" else { throw PhoneAuthError.invalidCode }
    }
}

// MARK: - ViewModel

@Observable @MainActor
final class PhoneAuthViewModel {
    enum Stage: Equatable { case phone, otp }
    enum Status: Equatable { case idle, sending, verifying, failed(String) }

    private(set) var stage: Stage = .phone
    private(set) var status: Status = .idle

    var countryCode: String = "+91"
    var national: String = ""
    var code: String = ""

    private let repository: PhoneAuthRepository

    init(repository: PhoneAuthRepository) { self.repository = repository }

    var phone: PhoneNumber {
        PhoneNumber(countryCode: countryCode, national: national.filter(\.isNumber))
    }

    var canSendCode: Bool { phone.isValid && status != .sending }
    var canVerify: Bool { code.count == 4 && status != .verifying }
    var errorMessage: String? {
        if case .failed(let msg) = status { return msg }
        return nil
    }

    func sendCode() async {
        guard canSendCode else { return }
        status = .sending
        do {
            try await repository.sendCode(to: phone)
            stage = .otp
            status = .idle
            code = ""
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func verifyCode() async -> Bool {
        guard canVerify else { return false }
        status = .verifying
        do {
            try await repository.verify(code: code, for: phone)
            status = .idle
            return true
        } catch {
            status = .failed(error.localizedDescription)
            return false
        }
    }

    func backToPhone() {
        stage = .phone
        code = ""
        status = .idle
    }
}
