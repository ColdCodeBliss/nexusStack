//
//  ThemeStore.swift
//  OE Hub
//

import SwiftUI
import StoreKit

// Centralize product IDs to avoid typos and ease future expansion.
private enum PID {
    static let midnightNeon = "com.coldcodebliss.nexusstack.theme.midnightNeon"
}

// If/when you add more theme IAPs, append here.
private let productIDs: Set<String> = [PID.midnightNeon]

@MainActor
final class ThemeStore: ObservableObject {
    // MARK: - Published state
    @Published var products: [Product] = []
    @Published var purchased: Set<String> = []
    @Published var isLoading = false
    @Published var lastMessage: String?

    // MARK: - Live updates
    private var updatesTask: Task<Void, Never>?

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Computed helpers
    var midnightNeonProduct: Product? {
        products.first(where: { $0.id == PID.midnightNeon })
    }

    var isMidnightNeonUnlocked: Bool {
        purchased.contains(PID.midnightNeon)
    }

    // MARK: - Lifecycle
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: Array(productIDs))
            await refreshEntitlements()
            startObservingUpdates()
            lastMessage = nil
        } catch {
            lastMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }

    func startObservingUpdates() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                switch result {
                case .verified(let transaction):
                    guard productIDs.contains(transaction.productID) else { continue }
                    await MainActor.run {
                        _ = self.purchased.insert(transaction.productID)
                    }
                    await transaction.finish()
                    // Optional: auto-select when update for Midnight Neon arrives
                    // if transaction.productID == PID.midnightNeon { ThemeManager.shared.select(.midnightNeon) }
                case .unverified:
                    // Ignore unverified updates; keep UI stable.
                    break
                }
            }
        }
    }

    // Current entitlements are perfect for non-consumables
    func refreshEntitlements() async {
        var owned = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result,
               productIDs.contains(t.productID),
               t.revocationDate == nil {
                owned.insert(t.productID)
            }
        }
        purchased = owned
    }

    // MARK: - Purchasing
    /// Purchases the Midnight Neon theme and selects it on success.
    /// - Returns: `true` if unlocked & applied.
    @discardableResult
    func purchaseMidnightNeon(theme: ThemeManager) async -> Bool {
        guard let product = midnightNeonProduct else {
            lastMessage = "Product unavailable"
            return false
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    purchased.insert(transaction.productID)
                    await transaction.finish()
                    // Apply the theme immediately
                    theme.select(.midnightNeon)
                    lastMessage = "Midnight Neon unlocked"
                    return true
                case .unverified:
                    lastMessage = "Purchase could not be verified"
                    return false
                }
            case .userCancelled:
                lastMessage = "Purchase cancelled"
                return false
            case .pending:
                lastMessage = "Purchase pending"
                return false
            @unknown default:
                lastMessage = "Purchase failed"
                return false
            }
        } catch {
            lastMessage = "Purchase error: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Restore
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            lastMessage = "Purchases restored"
        } catch {
            lastMessage = "Restore failed: \(error.localizedDescription)"
        }
    }
}
