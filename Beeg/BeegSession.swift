import Foundation
import SwiftUI

@MainActor
final class BeegSession: ObservableObject {
    static let shared = BeegSession()

    @Published private(set) var account: BeegAccount?
    @Published var message: String?

    private let key = "beeg.account"
    private let client = BeegClient()

    private init() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(BeegAccount.self, from: data),
              !saved.token.isEmpty else { return }
        account = saved
    }

    var isLoggedIn: Bool { account != nil }
    nonisolated var token: String? {
        UserDefaults.standard.string(forKey: "beeg.token")
    }

    func login(email: String, password: String) async -> Bool {
        do {
            let account = try await client.login(email: email, password: password)
            save(account)
            message = nil
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    func signup(email: String, password: String) async -> Bool {
        do {
            try await client.signup(email: email, password: password)
            return await login(email: email, password: password)
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    func logout() async {
        await client.logout()
        account = nil
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: "beeg.token")
    }

    private func save(_ account: BeegAccount) {
        self.account = account
        if let data = try? JSONEncoder().encode(account) {
            UserDefaults.standard.set(data, forKey: key)
        }
        UserDefaults.standard.set(account.token, forKey: "beeg.token")
    }
}
