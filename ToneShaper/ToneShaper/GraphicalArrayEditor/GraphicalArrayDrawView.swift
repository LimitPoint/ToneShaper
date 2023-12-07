//
//  GraphicalArrayDrawView.swift
//  Epicycles
//
//  Created by Joseph Pagliaro on 6/10/23.
//

import SwiftUI

struct GraphicalArrayDrawView: View {
    
    @ObservedObject var viewModel:GraphicalArrayModel
    
    @State var points: [CGPoint] = []
    @State var viewSize: CGSize = .zero
    
    @State var threshold: Double = 30.0
    
    var onApply: (([CGPoint], CGSize) -> Void)
    
    func erasePoints() {
        points = []
    }
    
        // Function to update the view size
    func updateViewSize(to size: CGSize) {
        viewSize = size
    }
    
    func pathForPoints() -> Path {
        
        guard points.count > 0 else  {
            return Path()
        }
        
        return Path { path in
            for index in 0...points.count-1  {
                let point = points[index]
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }
    
    func updatePoints(size:CGSize) {
        if let boundingRect = BoundingRect(points: points) {
            points = ScalePointsIntoView(points:[points], boundingRect: boundingRect, viewSize: CGSize(width: size.width, height: size.height), inset: 0)[0]
        }
    }
        
    @State var currentPoint:CGPoint = .zero
    
    @State var lastAddedPoint: CGPoint?
    
    func insertOrUpdatePoint(_ p: CGPoint, inSortedArray A: inout [CGPoint], withThreshold T: CGFloat) {
        
        let insertionIndex = binarySearch(for: p.x, in: A)
        
        if insertionIndex < A.count && A[insertionIndex].x == p.x {
                // If a point with the same x-coordinate exists, update its y-coordinate
            A[insertionIndex].y = p.y
        } else {
                // Check if the new point is far enough from existing points
            let isFarEnough = A.allSatisfy { existingPoint in
                let distance = sqrt(pow(existingPoint.x - p.x, 2) + pow(existingPoint.y - p.y, 2))
                return distance >= T
            }
            
            if isFarEnough {
                    // Insert the new point only if it's far enough from existing points
                A.insert(p, at: insertionIndex)
                
                if let lastPoint = lastAddedPoint {
                    A = A.filter { $0.x < p.x || $0.x > lastPoint.x }
                } else {
                    A = A.filter { $0.x < p.x }
                }
                
                lastAddedPoint = p
            }
        }
    }
    
    func adjustCGPointArray(_ points: inout [CGPoint], toWidth W: CGFloat) {
            // Check if the x coordinate of the first point is not 0
        if let firstPoint = points.first, firstPoint.x != 0 {
                // Insert a new point at the beginning with x coordinate 0
            let newPoint = CGPoint(x: 0, y: firstPoint.y)
            points.insert(newPoint, at: 0)
        }
        
            // Check if the x coordinate of the last point is not W
        if let lastPoint = points.last, lastPoint.x != W {
                // Insert a new point at the end with x coordinate W
            let newPoint = CGPoint(x: W, y: lastPoint.y)
            points.append(newPoint)
        }
        
            // Check if the y coordinate of the first point matches the y coordinate of the second point (if available)
        if points.count >= 2 && points[0].y != points[1].y {
            points[0].y = points[1].y
        }
        
            // Check if the y coordinate of the last point matches the y coordinate of the second to last point (if available)
        if points.count >= 2 && points[points.count - 1].y != points[points.count - 2].y {
            points[points.count - 1].y = points[points.count - 2].y
        }
    }
    
    
    func binarySearch(for targetX: CGFloat, in points: [CGPoint]) -> Int {
        var left = 0
        var right = points.count
        
        while left < right {
            let mid = left + (right - left) / 2
            
            if points[mid].x < targetX {
                left = mid + 1
            } else {
                right = mid
            }
        }
        
        return left
    }
    
    var drawView: some View {
        GeometryReader { geometry in
            
            ZStack(alignment: .bottomLeading) {
                
                pathForPoints()
                    .stroke(Color.red, lineWidth: 2)
                    .background(subtleMistColor)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                currentPoint = value.location
                                if currentPoint.x > 0 && currentPoint.x < geometry.size.width {
                                    if currentPoint.y > 0 && currentPoint.y < geometry.size.height {
                                        
                                        insertOrUpdatePoint(currentPoint, inSortedArray: &points, withThreshold: threshold)
                                    }
                                }
                                
                            }
                            .onEnded { _ in
                                adjustCGPointArray(&points, toWidth: geometry.size.width)
                            }
                    )
                
                    // Overlay black circles at specified points
                ForEach(points.indices, id: \.self) { index in
                    let point = points[index]
                    Circle()
                        .fill(Color.black)
                        .frame(width: 10, height: 10) // Adjust the size as needed
                        .position(point) // Place the circle at the specified point
                }   
            }
            .onChange(of: geometry.size) { newSize in
                updatePoints(size: newSize)
                updateViewSize(to: newSize)
            }
            .onAppear {
                updateViewSize(to: geometry.size)
            }
        }
        .border(.blue)
    }
    
    var menuView: some View {
        HStack(spacing: 16.0) {
            
            // Apply
            Button(action: {
                if points.count == 0 {
                    viewModel.alertInfo = GAAlertInfo(id: .canNotApply, title: "No Points", message: "There are no points to apply. Drag to draw points.", action: {
                        
                    })
                }
                else {
                    viewModel.alertInfo = GAAlertInfo(id: .apply, title: "Apply Points", message: "Are you sure you want to apply the points?", action: {
                        onApply(points, viewSize)
                    })
                }
                
            }) {
                VStack{
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.green, .gray)
                        .frame(width: 24, height: 24)
                    Text("Apply")
                }
            }
            
            // Clear
            Button(action: {
                viewModel.alertInfo = GAAlertInfo(id: .apply, title: "Erase Points", message: "Are you sure you want to erase the points?", action: {
                    erasePoints()
                })
            }) {
                VStack{
                    Image(systemName: "clear")
                        .foregroundStyle(.red, .gray)
                        .frame(width: 24, height: 24)
                    Text("Clear")
                }
            }
            .disabled(points.count == 0)
            .animation(.easeInOut, value: points)
            
            Text(" \(points.count)")
                .monospacedDigit()
            
            // Threshold
            Slider(value: $threshold, in: 5...50)
                .frame(width:100)
        }
        .padding(4)
        .buttonStyle(PlainButtonStyle())
        .background(
            Rectangle()
                .fill(creamsicleColor)
                .cornerRadius(10)
                .shadow(color: Color.gray.opacity(0.5), radius: 3, x: 5, y: 5)
                .opacity(0.5)
        )
    }
    
    var body: some View {
        CornerSnappingView { 
            ZStack {
                drawView
                if points.count == 0 {
                    VStack {
                        Spacer()
                        Text("Drag to draw here.")
                            .padding()
                        Text("Then apply to set the tone shape curve.")
                            .padding()
                    }
                    
                }
            }
           
        } snappingView: { 
            menuView
                //.opacity(points.count > 0 ? 1.0 : 0.0)
                //.animation(.easeInOut, value: points)
        }
    }
}

struct GraphicalArrayDrawView_Previews: PreviewProvider {
    static var previews: some View {
        GraphicalArrayDrawView(viewModel: GraphicalArrayModel(data: kDefaultModelData), onApply: { _, _ in
        })
        .frame(width: 350, height: 200)
    }
}
