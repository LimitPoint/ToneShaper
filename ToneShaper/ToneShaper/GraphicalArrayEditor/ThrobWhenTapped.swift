//
//  ThrobWhenTapped.swift
//  GraphicalArrayEditor
//
//  Created by Joseph Pagliaro on 9/2/23.
//

import SwiftUI

    // Throb Animation Modifier
struct ThrobWhenTapped: ViewModifier {
    @State private var isAnimating = false
    
    var onTap: () -> Void // Closure to handle tap actions
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 3 : 1.0)
            .onTapGesture {
                withAnimation {
                    isAnimating.toggle()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation {
                        isAnimating.toggle()
                    }
                }
                onTap() // Execute the provided closure on tap
            }
    }
}

extension View {
    func throbWhenTapped(onTap: @escaping () -> Void) -> some View {
        self.modifier(ThrobWhenTapped(onTap: onTap))
    }
}

struct ThrobWhenTappedView: View {
    @State private var circleSelected = false
    @State private var rectangleSelected = false
    
    var body: some View {
        VStack {
            Circle()
                .foregroundColor(circleSelected ? Color.red : Color.black)
                .frame(width: 50, height: 50)
                .throbWhenTapped {
                    circleSelected.toggle()
                }
                .padding()
            
            Rectangle()
                .foregroundColor(rectangleSelected ? Color.red : Color.black)
                .frame(width: 100, height: 50)
                .throbWhenTapped {
                    rectangleSelected.toggle()
                }
                .padding()
        }
    }
}

struct ThrobWhenTappedView_Previews: PreviewProvider {
    static var previews: some View {
        ThrobWhenTappedView()
    }
}
