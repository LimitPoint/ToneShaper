//
//  ThrobbingText.swift
//  ToneShaper
//
//  Created by Joseph Pagliaro on 10/23/23.
//

import SwiftUI

struct ThrobbingText: View {
    @State private var isRed = false
    let colors: [Color] = [.black, .red]
    let text: String
    let maxCycles: Int  // Define the maximum number of cycles
    @State private var cycleCount = 0  // Counter to track cycles
    
    var body: some View {
        Text(text)
            .foregroundColor(isRed ? .red : .black)
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.isRed.toggle()
                    }
                    self.cycleCount += 1
                    if self.cycleCount >= self.maxCycles {
                        timer.invalidate()  // Stop the timer after reaching the desired cycles
                        self.isRed = false
                    }
                }
            }
    }
}

#Preview("ThrobbingText") {
    ThrobbingText(text: "Hello World", maxCycles: 7)
        .font(.caption)
}
