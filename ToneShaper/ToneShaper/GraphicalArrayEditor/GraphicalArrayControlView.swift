//
//  GraphicalArrayControlView.swift
//  GraphicalArrayEditor
//
//  Created by Joseph Pagliaro on 9/7/23.
//

import SwiftUI
import AVFoundation

struct ControlViewFrequencyRangeView: View {
    
    @ObservedObject var viewModel:GraphicalArrayModel
    
    @State var frequencyRange: ClosedRange<Double> = 0...0
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        VStack {
            FrequencyRangePicker(viewModel: viewModel, rangedSliderViewChanged: { 
                viewModel.registerUndoForFrequencyRangeSlider(oldRange: frequencyRange, undoManager: undoManager)
                frequencyRange = viewModel.minFrequency...viewModel.maxFrequency
                viewModel.graphicalArrayDelegate?.graphicalArrayFrequencyRangeChanged()
            })
            .padding()
            .onAppear {
                frequencyRange = viewModel.minFrequency...viewModel.maxFrequency
            }
        }
    }
}

struct ControlViewDurationView: View {
    
    @ObservedObject var viewModel:GraphicalArrayModel
    
    @Environment(\.undoManager) var undoManager
    
    @State var sliderValue:Double = 0
    @State var oldValue:Double = 0
    @State private var isEditing = false
    
    // For a < b < c, linearly map interval [0,0.5] to interval [a,b], and linearly map interval [0.5,1.0] to interval [b,c]
    func f(_ x: Double, a: Double, b: Double, c: Double) -> Double {
        
        guard a < b && b < c else {
            return a
        }
        
        if x >= 0.0 && x <= 0.5 {
                // Linearly map [0, 0.5] to [a, b]
            return a + (x - 0.0) * (b - a) / (0.5 - 0.0)
        } else if x > 0.5 && x <= 1.0 {
                // Linearly map [0.5, 1.0] to [b, c]
            return b + (x - 0.5) * (c - b) / (1.0 - 0.5)
        } else if x < 0 {
            return a
        }
        
        return b
    }
    
    func inverse_f(_ y: Double, a: Double, b: Double, c: Double) -> Double {
        
        guard a < b && b < c else {
            return 0
        }
        
        if y >= a && y <= b {
                // Inverse map [a, b] to [0, 0.5]
            return 0.0 + (y - a) * (0.5 - 0.0) / (b - a)
        } else if y > b && y <= c {
                // Inverse map [b, c] to [0.5, 1.0]
            return 0.5 + (y - b) * (1.0 - 0.5) / (c - b)
        } else if y < a {
            return 0
        }
        
        return 1
    }
    
        // [0,1] -> durationRange, first half to [lowerBound,1]
    func durationForSliderValue(_ sliderValue: Double) -> Double {
        return f(sliderValue, a: durationRange.lowerBound, b: 1, c: durationRange.upperBound)
    }
    
        // durationRange -> [0,1]
    func sliderValueForDuration(_ duration: Double) -> Double {
        let value = inverse_f(duration, a: durationRange.lowerBound, b: 1, c: durationRange.upperBound)
        return  min(max(value, durationRange.lowerBound), durationRange.upperBound)
    }
        
    var body: some View {
        
        VStack {
            
            HStack {
                Text("\(viewModel.duration, specifier: "%.2f")")
                
                Spacer() 
                
                Button(action: {
                    
                    oldValue = viewModel.duration
                    
                    if viewModel.duration < 1 {
                        viewModel.duration = min(max( round(viewModel.duration * 10) / 10, durationRange.lowerBound), durationRange.upperBound) // round to nearest 10th, but limited to durationRange
                    }
                    else {
                        viewModel.duration = min(max(round(viewModel.duration), durationRange.lowerBound), durationRange.upperBound) // round to nearest integer, but limited to durationRange
                    }
                    
                    viewModel.registerUndoForDurationSlider(oldValue: oldValue, undoManager: undoManager)
                    viewModel.graphicalArrayDelegate?.graphicalArrayDurationChanged()
                }) {
                    HStack {
                        Text("Round")
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
                
            }
            
            Slider(value: $sliderValue, in: 0.0...1.0,
                   onEditingChanged: { editing in
                isEditing = editing
                if editing == false { // handle when editing ended
                    viewModel.registerUndoForDurationSlider(oldValue: oldValue, undoManager: undoManager)
                    viewModel.graphicalArrayDelegate?.graphicalArrayDurationChanged()
                    oldValue = viewModel.duration
                }
            })
            .onChange(of: sliderValue) { newSliderValue in
                if isEditing { // manual changes
                    viewModel.duration = durationForSliderValue(sliderValue)
                }
            }
            .onChange(of: viewModel.duration) { duration in 
                if isEditing == false { 
                    sliderValue = sliderValueForDuration(duration)
                }
            }
            .onAppear {
                sliderValue = sliderValueForDuration(viewModel.duration)
                oldValue = viewModel.duration
            }
            
            Text("(Echo Offset: \(String(format: "%.2f", viewModel.echoOffsetTimeSeconds)) s)")
                .font(.caption)
                .monospacedDigit()
            
            Text(kEchoOffsetOptionNote)
                .font(.caption)
                .padding()
        } 
        .padding()
    }
}


struct GraphicalArrayControlView: View {
    @ObservedObject var viewModel:GraphicalArrayModel
    
    @State private var scrollOffset: CGFloat = 0
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        
        ScrollViewReader { scrollViewProxy in
            ScrollView {
                VStack {
                    
                    DisclosureGroup("Selection", isExpanded: $viewModel.isSelectionViewExpanded) {
                        GraphicalArraySelectionControlView(viewModel: viewModel)
                    }
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.5), value: viewModel.isSelectionViewExpanded)
                    .customBorderStyle()
                    
                    DisclosureGroup("Note Editor", isExpanded: $viewModel.isNotePickerViewExpanded) {
                        GraphicalArrayNotePickerView(viewModel: viewModel)
                    }
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.5), value: viewModel.isNotePickerViewExpanded)
                    .customBorderStyle()
                   
                    DisclosureGroup("Options", isExpanded: $viewModel.isOptionsViewExpanded) {
                        GraphicalArrayOptionsView(viewModel: viewModel)
                    }
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.5), value: viewModel.isOptionsViewExpanded)
                    .customBorderStyle()
                    
                    DisclosureGroup("Frequency Range", isExpanded: $viewModel.isFrequencyRangeViewExpanded) {
                        ControlViewFrequencyRangeView(viewModel: viewModel)
                    }
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.5), value: viewModel.isFrequencyRangeViewExpanded)
                    .customBorderStyle()
                    
                    DisclosureGroup("Tone Shape Duration", isExpanded: $viewModel.isDurationViewExpanded) {
                        ControlViewDurationView(viewModel: viewModel)
                    }
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.5), value: viewModel.isDurationViewExpanded)
                    .customBorderStyle()
                    
                    DisclosureGroup("Export Tone Shape", isExpanded: $viewModel.isExportViewExpanded) {
                        GraphicalArrayExportView(viewModel: viewModel)
                    }
                    .padding(.horizontal)
                    .id("Bottom") // used to scroll when the DisclosureGroup is opened (since at bottom)
                    
                    .animation(.easeInOut(duration: 0.5), value: viewModel.isExportViewExpanded)
                    .onChange(of: viewModel.isExportViewExpanded, perform: { newExportViewExpanded in
                        if newExportViewExpanded == true {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation {
                                    scrollViewProxy.scrollTo("Bottom", anchor: .top)
                                }
                            }
                        }
                    })   
                    .customBorderStyle()
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            .fileExporter(isPresented: $viewModel.showAudioExporter, document: viewModel.audioDocument, contentType: (viewModel.exportLinearPCM ? UTType.wav : UTType.mpeg4Audio), defaultFilename: viewModel.audioDocument?.filename) { result in
                if case .success = result {
                    do {
                        let exportedURL: URL = try result.get()
                        viewModel.alertInfo = GAAlertInfo(id: .exporterSuccess, title: "Audio Saved", message: exportedURL.lastPathComponent, action: {})
                    }
                    catch {
                        viewModel.alertInfo = GAAlertInfo(id: .exporterFailed, title: "Audio Not Saved", message: (viewModel.audioDocument?.filename ?? ""), action: {})
                    }
                } else {
                    viewModel.alertInfo = GAAlertInfo(id: .exporterFailed, title: "Audio Not Saved", message: (viewModel.audioDocument?.filename ?? ""), action: {})
                }
            }
        }
    }
}

struct GraphicalArrayControlView_Previews: PreviewProvider {
    static var previews: some View {
        GraphicalArrayControlView(viewModel: GraphicalArrayModel(data: kDefaultModelData))
    }
}

struct ControlViewFrequencyRangeViewPreviews: PreviewProvider {
    static var previews: some View {
        ControlViewFrequencyRangeView(viewModel: GraphicalArrayModel(data: kDefaultModelData))
    }
}

struct ControlViewDurationView_Previews: PreviewProvider {
    static var previews: some View {
        ControlViewDurationView(viewModel: GraphicalArrayModel(data: kDefaultModelData))
    }
}



