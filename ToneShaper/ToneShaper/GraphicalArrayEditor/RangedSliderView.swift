//
//  RangedSliderView.swift
//  GraphicalArrayEditor
//
//  Created by Joseph Pagliaro on 8/28/23.
//  Based on RangedSliderView from TimeWarpEditor. Non-linear frequency mapping taken from TonePlayer.

import SwiftUI

let kRangePrecisonDisplay = "%.2f"

let kThumbwidth:CGFloat = 10
let kThumbheight:CGFloat = 20
let kThumbcolor:Color = Color(red: 0.5, green: 0.5, blue: 0.5, opacity: 0.8)

struct RangedSliderView: View {
    
    var incrementCount:Int
    @Binding var incrementCountRange:ClosedRange<Double>
    var rangedSliderViewChanged:(()->())?
    var displayRangeForIncrementCountRange:()->ClosedRange<Double>
    
    var body: some View {
        GeometryReader { geometry in
            sliderView(sliderSize: geometry.size)
        }
    }
    
    @ViewBuilder private func sliderView(sliderSize: CGSize) -> some View {
        let sliderViewYCenter = sliderSize.height / 2
        
        let sliderBounds = 1...incrementCount
        
        ZStack {
            let sliderBoundDifference = sliderBounds.count //- 1
            let stepWidthInPixel = CGFloat(sliderSize.width) / CGFloat(sliderBoundDifference)
            
                // Calculate Left Thumb initial position
            let leftThumbLocation: CGFloat = $incrementCountRange.wrappedValue.lowerBound == Double(sliderBounds.lowerBound)
            ? 0
            : CGFloat($incrementCountRange.wrappedValue.lowerBound - Double(sliderBounds.lowerBound)) * stepWidthInPixel
            
                // Calculate right thumb initial position
            let rightThumbLocation = CGFloat($incrementCountRange.wrappedValue.upperBound) * stepWidthInPixel
            
                // Paths between and outside both handles
            linesForThumbs(from: .init(x: leftThumbLocation, y: sliderViewYCenter), to: .init(x: rightThumbLocation, y: sliderViewYCenter), sliderSize: sliderSize)
            
                // Left Thumb Handle
            let leftThumbPoint = CGPoint(x: leftThumbLocation, y: sliderViewYCenter)
            
            thumbView(position: leftThumbPoint, displayValue: displayRangeForIncrementCountRange().lowerBound, above: false)
                .highPriorityGesture(DragGesture().onChanged({ dragValue in
                    
                    let dragLocation = dragValue.location
                    let xThumbOffset = min(max(0, dragLocation.x), sliderSize.width)
                    
                    let newValue = Double(sliderBounds.lowerBound) + Double(xThumbOffset / stepWidthInPixel)
                    
                        // Stop the range thumbs from colliding each other
                    if newValue < incrementCountRange.upperBound - (kThumbwidth / stepWidthInPixel) {
                        incrementCountRange = newValue...incrementCountRange.upperBound
                    }
                })
                    .onEnded({ _ in
                        if let rangedSliderViewChanged = rangedSliderViewChanged {
                            rangedSliderViewChanged()
                        }
                    })
                )
            
                // Right Thumb Handle
            thumbView(position: CGPoint(x: rightThumbLocation, y: sliderViewYCenter), displayValue: displayRangeForIncrementCountRange().upperBound, above: true)
                .highPriorityGesture(DragGesture().onChanged({ dragValue in
                    
                    let dragLocation = dragValue.location
                    let xThumbOffset = min(max(CGFloat(leftThumbLocation), dragLocation.x), sliderSize.width)
                    
                    var newValue = Double(xThumbOffset / stepWidthInPixel) // convert back the value bound
                    newValue = min(newValue, Double(sliderBounds.upperBound))
                    
                        // Stop the range thumbs from colliding each other
                    if newValue > incrementCountRange.lowerBound + (kThumbwidth / stepWidthInPixel) {
                        incrementCountRange = incrementCountRange.lowerBound...newValue
                    }
                })
                    .onEnded({ _ in
                        if let rangedSliderViewChanged = rangedSliderViewChanged {
                            rangedSliderViewChanged()
                        }
                    })
                )
        }
    }
    
    @ViewBuilder func linesForThumbs(from: CGPoint, to: CGPoint, sliderSize: CGSize) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: from.y))
            path.addLine(to: CGPoint(x: sliderSize.width, y: from.y))
        }
        .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(Color.red, lineWidth: 4)
    }
    
    @ViewBuilder func thumbView(position: CGPoint, displayValue: Double, above:Bool) -> some View {
        ZStack {
            Text(String(format: kRangePrecisonDisplay, displayValue))
                .font(.system(size: 10))
                .offset(y: (above ? -20 : 20))
            
            Capsule()
                .frame(width: kThumbwidth, height: kThumbheight)
                .foregroundColor(kThumbcolor)
        }
        .position(x: position.x, y: position.y)
    }
}

struct RangedSliderView_Wrapper: View {
    
    @State var sliderPosition: ClosedRange<Double> = 1.0...100.0
    
    var body: some View {
        RangedSliderView(incrementCount: 100, incrementCountRange: $sliderPosition, rangedSliderViewChanged: { 
            
        }, displayRangeForIncrementCountRange: {
            1.0...100.0
        })
        
    }
}

struct RangedSliderView_Previews: PreviewProvider {
    static var previews: some View {
        RangedSliderView_Wrapper()
            .padding()
    }
}
