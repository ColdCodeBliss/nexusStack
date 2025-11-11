//
//  DonationStore.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/19/25.
//


import Foundation
import StoreKit

@MainActor
final class DonationStore: ObservableObject {
    // ⬅️ Replace these with your real Product IDs from App Store Connect
    // Recommended naming: <bundleID> .tip.2, tip.5, .tip.10, .tip.20
    private let productIDs: Set<String> = [
        "com.coldcodebliss.nexusstack.tip.2",
        "com.coldcodebliss.nexusstack.tip.5",
        "com.coldcodebliss.nexusstack.tip.10"
        //"com.coldcodebliss.nexusstack.tip.20"
    ]

    @Published var isLoading = false
    @Published var products: [Product] = []
    @Published var lastMessage: String?

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await Product.products(for: Array(productIDs))
            // Keep a consistent order: $5, $10, $20 by price ascending
            products = fetched.sorted(by: { $0.price < $1.price })
        } catch {
            lastMessage = "Unable to load donation options. (\(error.localizedDescription))"
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    lastMessage = "Thanks for your support! 🙏"
                    await transaction.finish()
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
}
