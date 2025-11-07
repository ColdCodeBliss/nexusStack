//
//  GlassSurfaces.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/24/25.
//

import SwiftUI

@available(iOS 26.0, *)
extension View {
    func glassButton() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

func color(for index: Int) -> Color {
    let count = Job.ColorCode.ordered.count
    let clamped = max(0, min(index, count - 1))
    let name = Job.ColorCode.name(for: clamped)
    return color(for: name)   // calls your String? → Color mapper in Utilities.swift
}



func tsFormattedDate(_ date: Date) -> String {
    let df = DateFormatter()
    df.dateFormat = "MM/dd/yyyy"
    return df.string(from: date)
}

