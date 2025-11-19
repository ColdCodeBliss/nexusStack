//
//  NexusStackWidgetsBundle.swift
//  NexusStackWidgets
//
//  Created by Ryan Bliss on 11/18/25.
//

import WidgetKit
import SwiftUI

@main
struct NexusStackWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NexusStackWidgets()
        NexusStackWidgetsControl()
        NexusStackWidgetsLiveActivity()
    }
}
