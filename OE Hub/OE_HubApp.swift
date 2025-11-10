//
//  OE_HubApp.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/5/25.
//

import SwiftUI
import SwiftData

@main
struct OE_HubApp: App {
    
    @StateObject private var theme = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .modelContainer(for: [Job.self, Deliverable.self, ChecklistItem.self, MindNode.self, Note.self])
                .environmentObject(theme)
        }
    }
}
