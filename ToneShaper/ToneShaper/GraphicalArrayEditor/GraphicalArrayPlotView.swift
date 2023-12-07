//
//  GraphicalArrayPlotView.swift
//  GraphicalArrayEditor
//
//  Created by Joseph Pagliaro on 9/7/23.
//

import SwiftUI

let indicatorLineWidth:Double = 2
let veryPaleRed = Color(Color.RGBColorSpace.sRGB, red: 1, green: 0, blue: 0, opacity: 0.1)

struct GraphicalArrayPlotView: View {
    @ObservedObject var viewModel:GraphicalArrayModel
    
    @State var draggedCircleIndex: Int? // Initialize the dragged circle index as an optional
    @State var originalDraggedPoint: CGPoint?
    @State var dragStarted = false
    
    @Environment(\.undoManager) var undoManager
    
    var menuView: some View {
        
        HStack {
            
                // show time and frequency of point dragged or the number of points
            if let draggedIndex = draggedCircleIndex {
                HStack {
                    Text(String(format: "%.2f", viewModel.points[draggedIndex].y))
                    
                    Text(String(format: "%.2f", viewModel.points[draggedIndex].x))
                    
                }
                .monospacedDigit()
                .font(.caption)
            }
            else {
                Text("\(viewModel.selectedPointIndices.count) \\ \(viewModel.points.count)")
                    .monospacedDigit()
                
            }
            
            Button(action: {
                viewModel.loopCount = 1
                viewModel.playToneShape()
            }, label: {
                HStack {
                    Image(systemName: "play.square.fill")
                        .foregroundStyle(.white, .gray)
                }
            })
            
            Button(action: {
                viewModel.stopAudioPlayer()
            }, label: {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.red, .gray)
            })
            .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
        
                // reset all to factory defaults
            
            Button(action: {
                viewModel.alertInfo = GAAlertInfo(id: .reset, title: "Reset", message: "Are you sure you want to reset points and controls to default values?", action: {
                    viewModel.reset(undoManager: undoManager)
                    viewModel.graphicalArrayDelegate?.graphicalArrayDataLoaded()
                })
            }, label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(.red, .gray)
                }
            })
            .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
            .disabled(viewModel.resetAvailable()) // Disable the button
            .opacity(viewModel.resetAvailable() ? 0.5 : 1.0)
            
            Button(action: {
                viewModel.alertInfo = GAAlertInfo(id: .stepped, title: "Step Function", message: "Are you sure you want to convert points to a step function?", action: {
                    if viewModel.convertPointsToSteps(undoManager: undoManager) {
                        viewModel.graphicalArrayDelegate?.graphicalArrayPointAdded()
                    }
                    else {
                        DispatchQueue.main.async {
                            viewModel.alertInfo = GAAlertInfo(id: .canNotApply, title: "Step Function", message: "The points could not be converted to a step function.\n\nTry again after adjusting the frequency range or the tone shape duration.", action: {
                                
                            })
                        }
                    }
                })
            }, label: {
                HStack {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundStyle(.red, .gray)
                }
            })
            .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
            
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
    
    var plotView: some View {
        GeometryReader { geometry in
            ZStack {
                    // Draw lines connecting the points
                Path { path in
                    if !viewModel.points.isEmpty {
                        let startPoint = viewModel.LAV(viewModel.points[0])
                        path.move(to: startPoint)
                        for index in 1..<viewModel.points.count {
                            let point = viewModel.LAV(viewModel.points[index])
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(Color.black, lineWidth: 2)
                .transformEffect(.init(scaleX: 1, y: -1))
                .offset(y: geometry.size.height) // Offset to flip vertically
                
                    // Draw tone shape audio play indicator
                if viewModel.indicatorPercent > 0 {
                    
                    Path { path in 
                        path.addRect(CGRect(x: 0, y: 0, width: viewModel.indicatorPercent * geometry.size.width, height: geometry.size.height).insetBy(dx: 0, dy: -indicatorLineWidth/2))
                    }
                    .fill(veryPaleRed)
                    
                    Path { path in 
                        path.move(to: CGPoint(x: viewModel.indicatorPercent * geometry.size.width, y:  -indicatorLineWidth/2))
                        path.addLine(to: CGPoint(x: viewModel.indicatorPercent * geometry.size.width, y: geometry.size.height + indicatorLineWidth/2))
                    }
                    .stroke(Color.red, lineWidth: 2)
                }
                
                    // Draw circles for the points
                ForEach(viewModel.points.indices, id: \.self) { index in
                    
                    let isSelected = viewModel.selectedPointIndices.contains(index)
                    let isNote = frequencyIsNote(frequency: viewModel.points[index].y)
                    
                    let point = Binding(
                        get: {
                            viewModel.LAV(viewModel.points[index])
                        },
                        set: { newValue in
                            let scaledPoint = viewModel.LVA(newValue)
                            viewModel.points[index] = scaledPoint
                        }
                    )
                    
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.red : Color.black)
                            .frame(width: pointDiameter, height: pointDiameter)
                            .overlay(
                                Circle()
                                    .stroke(Color.green, lineWidth: isNote && viewModel.highlightNotes ? pointDiameter/4 : 0) 
                            )
                            .throbWhenTapped {
                                if viewModel.selectedPointIndices.contains(index) {
                                    viewModel.unselectPoint(at: index)
                                } else {
                                    viewModel.selectPoint(at: index)
                                }
                                
                                if viewModel.speakerOn {
                                    viewModel.playAudioIndex(index)
                                }
                            }
                            .position(
                                x: point.wrappedValue.x,
                                y: geometry.size.height - point.wrappedValue.y // Apply vertical flip
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { gesture in
                                        
                                        if !dragStarted {
                                            originalDraggedPoint = viewModel.points[index]
                                            
                                            if viewModel.speakerOn {
                                                viewModel.graphicalArrayDelegate?.graphicalArrayDraggingStarted()
                                            }
                                            
                                            dragStarted = true
                                        }
                                        
                                        draggedCircleIndex = index 
                                        
                                            //var newPoint = gesture.location
                                        var newPoint = CGPoint(
                                            x: gesture.location.x,
                                            y: geometry.size.height - gesture.location.y // Apply vertical flip
                                        )
                                        
                                        let draggedIndex = index
                                        
                                            // Calculate the allowed range based on neighbors in A's bounds
                                        if draggedIndex > 0 {
                                            let leftNeighborX = viewModel.LAV(viewModel.points[draggedIndex - 1]).x
                                            newPoint.x = max(leftNeighborX + 1, newPoint.x)
                                        }
                                        
                                        if draggedIndex < viewModel.points.count - 1 {
                                            let rightNeighborX = viewModel.LAV(viewModel.points[draggedIndex + 1]).x
                                            newPoint.x = min(rightNeighborX - 1, newPoint.x)
                                        }
                                        
                                            // Constrain x-coordinate within the view's bounds
                                        newPoint.x = max(0, min(viewModel.viewSize.width, newPoint.x))
                                        
                                            // Constrain y-coordinate within the view's bounds
                                        newPoint.y = max(0, min(viewModel.viewSize.height, newPoint.y))
                                        
                                            // If it's the first or last point, keep its x-coordinate unchanged
                                        if draggedIndex == 0 {
                                            newPoint.x = viewModel.LAV(viewModel.points[draggedIndex]).x
                                        } else if draggedIndex == viewModel.points.count - 1 {
                                            newPoint.x = viewModel.LAV(viewModel.points[draggedIndex]).x
                                        }
                                        
                                            // Update the dragged point's position
                                        viewModel.points[draggedIndex] = viewModel.LVA(newPoint)
                                        
                                        if viewModel.speakerOn {
                                            viewModel.graphicalArrayDelegate?.graphicalArrayIsDragging(frequency: viewModel.points[draggedIndex].y)
                                        }
                                       
                                    }
                                    .onEnded { _ in
                                        
                                        if let index = draggedCircleIndex, viewModel.speakerOn {
                                            viewModel.playAudioIndex(index)
                                        }
                                        
                                        
                                        if viewModel.speakerOn { 
                                            viewModel.graphicalArrayDelegate?.graphicalArrayDraggingEnded()
                                        }
                                        
                                        viewModel.registerUndoForDragging(index: draggedCircleIndex, oldPoint: originalDraggedPoint, undoManager: undoManager)
                                        
                                        draggedCircleIndex = nil
                                        originalDraggedPoint = nil
                                        dragStarted = false
                                    }
                            )
                        
                        if viewModel.labelType != .none {
                            
                            if viewModel.labelType == .frequencyAndNote {
                                if isNote {
                                    Text("\(pianoNoteForFrequency(viewModel.points[index].y))")
                                        .font(.caption)
                                        .foregroundColor(.black)
                                        .position(x: point.wrappedValue.x, y: geometry.size.height - (point.wrappedValue.y + 2 * labelOffset)) // Adjust the offset as needed
                                }
                            }
                            
                                // label with y-coordinate - i.e. frequency
                            Text(String(format: "%.2f", viewModel.points[index].y))
                                .font(.caption)
                                .foregroundColor(.black)
                                .position(x: point.wrappedValue.x, y: geometry.size.height - (point.wrappedValue.y + labelOffset)) // Adjust the offset as needed
                            
                                // label with x-coordinate - i.e. time
                            Text(String(format: "%.2f", viewModel.points[index].x))
                                .font(.caption)
                                .foregroundColor(.black)
                                .position(x: point.wrappedValue.x, y: geometry.size.height - (point.wrappedValue.y - labelOffset)) // Adjust the offset as needed
                        }
                        
                    }
                    
                }
            }
            .border(.blue)
            .background(Color.white) // otherwise can't tap!
            .onChange(of: geometry.size) { newSize in
                viewModel.updateViewSize(to: newSize)
            }
            .onAppear {
                viewModel.updateViewSize(to: geometry.size)
            }
            .onChange(of: viewModel) { newViewModel in
                newViewModel.updateViewSize(to: geometry.size)
            }
            .onTapGesture { tappedLocation in
                let flippedTappedLocation = CGPoint(
                    x: tappedLocation.x,
                    y: geometry.size.height - tappedLocation.y // Apply vertical flip
                )
                
                    // Check if the tap is within the ZStack's bounds before processing
                if CGRect(origin: .zero, size: geometry.size).contains(flippedTappedLocation) {
                    if isPointWithinDistance(flippedTappedLocation, viewModel.points, pointTapMinimumDistance, viewModel.LAV) == false {
                        viewModel.addPoint(at: flippedTappedLocation, undoManager: undoManager)
                        viewModel.graphicalArrayDelegate?.graphicalArrayPointAdded()
                    }
                    
                }
            }
        }
    }
    
    var body: some View {
        CornerSnappingView { 
            plotView
        } snappingView: { 
            menuView
        }
    }
}

struct GraphicalArrayPlotView_Previews: PreviewProvider {
    static var previews: some View {
        GraphicalArrayPlotView(viewModel: GraphicalArrayModel(data: kDefaultModelData))
            .padding(25)
    }
}

struct GraphicalArrayView_Previews: PreviewProvider {
    static var previews: some View {
        GraphicalArrayView(viewModel: GraphicalArrayModel(data: kDefaultModelData))
            .padding(25)
    }
}
