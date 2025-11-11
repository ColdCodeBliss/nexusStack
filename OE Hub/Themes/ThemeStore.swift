//
//  ThemeStore.swift
//  OE Hub
//
//  Created by Ryan Bliss on 11/9/25.
//


import Foundation
import StoreKit
import SwiftUI

@MainActor
final class ThemeStore: ObservableObject {

    // MARK: - Configure your product IDs
    // App Store Connect → In-App Purchases → Consumable/Non-consumable
    // For a theme, make this a **non-consumable**.
    private let productIDs: Set<String> = [
        "com.coldcodebliss.nexusstack.theme.midnightNeon"
    ]

    // MARK: - Published state
    @Published var isLoading = false
    @Published var products: [Product] = []
    @Published var purchased: Set<String> = []
    @Published var lastMessage: String?

    // Convenience accessors
    var midnightNeonProduct: Product? {
        products.first(where: { $0.id == "com.coldcodebliss.nexusstack.theme.midnightNeon" })
    }

    var isMidnightNeonUnlocked: Bool {
        purchased.contains("com.coldcodebliss.nexusstack.theme.midnightNeon")
    }

    // MARK: - Loading / Entitlements
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await Product.products(for: Array(productIDs))
            // Deterministic order if you later add more themes
            products = fetched.sorted(by: { $0.displayName < $1.displayName })
            await refreshEntitlements()
        } catch {
            lastMessage = "Unable to load themes. (\(error.localizedDescription))"
        }
    }

    func refreshEntitlements() async {
        var owned: Set<String> = []
        for id in productIDs {
            if let result = try? await Transaction.latest(for: id) {
                switch result {
                case .verified(let t):
                    if t.revocationDate == nil {
                        owned.insert(id)
                    }
                case .unverified:
                    break
                }
            }
        }
        purchased = owned
    }

    // MARK: - Purchase
    func purchaseMidnightNeon(theme: ThemeManager) async {
        guard let product = midnightNeonProduct else { return }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    purchased.insert(product.id)
                    await transaction.finish()
                    // Select immediately on success
                    theme.select(.midnightNeon)
                    lastMessage = "Midnight Neon unlocked. 🌌"
                case .unverified(_, let error):
                    lastMessage = "Purchase could not be verified. (\(error.localizedDescription))"
                }
            case .userCancelled:
                lastMessage = nil
            case .pending:
                lastMessage = "Your purchase is pending."
            @unknown default:
                lastMessage = "Unknown purchase state."
            }
        } catch {
            lastMessage = "Purchase failed. (\(error.localizedDescription))"
        }
    }

    // MARK: - Restore
    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            lastMessage = "Purchases restored."
        } catch {
            lastMessage = "Restore failed. (\(error.localizedDescription))"
        }
    }
}
