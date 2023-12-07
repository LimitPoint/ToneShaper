//
//  GraphicalArrayOptionsView.swift
//  ToneShaper
//
//  Created by Joseph Pagliaro on 10/19/23.
//

import SwiftUI

struct EchoOffsetSliderView: View {
    
    @ObservedObject var viewModel:GraphicalArrayModel
    
    @Environment(\.undoManager) var undoManager
    
    @State var isEditing = false
    @State var oldValue:Double = 0
    @State var sliderValue:Double = 0
    
    var body: some View {
            // Echo offfset in seconds
        VStack {
            
            HStack {
                Text("\(String(format: "%.2f", sliderValue)) s")
                    .monospacedDigit()
                
                Spacer() 
                
                Button(action: {
                    
                    oldValue = viewModel.echoOffsetTimeSeconds
                    
                    sliderValue = viewModel.duration / 2
                    
                    // update the model too
                    viewModel.echoOffsetTimeSeconds = sliderValue
                    viewModel.registerUndoForEchoOffsetSlider(oldValue: oldValue, undoManager: undoManager)
                    viewModel.graphicalArrayDelegate?.graphicalArrayEchoOffsetChanged()
                    
                }) {
                    HStack {
                        Text("Middle")
                        Image(systemName: "arrow.right.and.line.vertical.and.arrow.left")
                    }
                }
                
                Spacer()
                
                Button(action: {
                    
                    oldValue = viewModel.echoOffsetTimeSeconds
                    
                    if sliderValue < 1 {
                        sliderValue = round(sliderValue * 10) / 10 // round to nearest 10th
                    }
                    else {
                        sliderValue = min(round(sliderValue), viewModel.duration) // round to nearest integer, but limited by duration
                    }
                    
                    viewModel.echoOffsetTimeSeconds = sliderValue
                    viewModel.registerUndoForEchoOffsetSlider(oldValue: oldValue, undoManager: undoManager)
                    viewModel.graphicalArrayDelegate?.graphicalArrayEchoOffsetChanged()
                    
                }) {
                    HStack {
                        Text("Round")
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
                
            }
            
            Slider(value: $sliderValue, in: 0...viewModel.duration,
                   onEditingChanged: { editing in
                isEditing = editing
                if editing == false { // handle when editing ended
                    oldValue = viewModel.echoOffsetTimeSeconds
                    viewModel.echoOffsetTimeSeconds = sliderValue
                    viewModel.registerUndoForEchoOffsetSlider(oldValue: oldValue, undoManager: undoManager)
                    viewModel.graphicalArrayDelegate?.graphicalArrayEchoOffsetChanged()
                }
            })
            .onAppear {
                sliderValue = viewModel.echoOffsetTimeSeconds
            }
            .onChange(of: viewModel.echoOffsetTimeSeconds) { newEchoOffsetTimeSeconds in
                sliderValue = newEchoOffsetTimeSeconds
            }
            
            Text("(Tone Shape Duration: \(String(format: "%.2f", viewModel.duration)) s)")
                .font(.caption)
                .monospacedDigit()
            
            Text(kEchoOffsetOptionNote)
                .font(.caption)
                .padding()
            
            HStack {
                Text("Echo is symmetric around middle:")
                    .font(.caption)
                
                Button(action: {
                    
                    sliderValue = viewModel.duration - sliderValue
                    
                        // update the model too
                    let oldValue = viewModel.echoOffsetTimeSeconds
                    viewModel.echoOffsetTimeSeconds = sliderValue
                    viewModel.registerUndoForEchoOffsetSlider(oldValue: oldValue, undoManager: undoManager)
                    viewModel.graphicalArrayDelegate?.graphicalArrayEchoOffsetChanged()
                    
                }) {
                    HStack {
                        Text("Flip")
                            .font(.caption)
                            .foregroundStyle(.blue, .gray)
                        Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                    }
                }
            }
        }
    }
}

struct EchoVolumeSliderView: View {
    
    @ObservedObject var viewModel:GraphicalArrayModel
    
    @Environment(\.undoManager) var undoManager
    
    @State var isEditing = false
    @State var oldValue:Double = 0
    @State var sliderValue = 1.0
    
    var body: some View {
        VStack {
            HStack {
                Text("\(String(format: "%.2f", viewModel.echoVolume))")
                    .monospacedDigit()
                
                Spacer() 
            }
            
            Slider(value: $sliderValue, in: 0.0...1.0,
                   onEditingChanged: { editing in
                isEditing = editing
                if editing == false {
                    viewModel.registerUndoForEchoVolumeSlider(oldValue: oldValue, undoManager: undoManager)
                    viewModel.graphicalArrayDelegate?.graphicalArrayEchoVolumeChanged()
                    oldValue = viewModel.echoVolume
                }
            })
            .onChange(of: sliderValue) { new_echoVolumeSliderValue in
                viewModel.echoVolume = pow(new_echoVolumeSliderValue, 2)
            }
        }
        .onChange(of: viewModel.echoVolume) { new_echoVolume in
            if new_echoVolume != pow(sliderValue, 2) {
                sliderValue = sqrt(new_echoVolume)
            }
        }
        .onAppear {
            oldValue = viewModel.echoVolume
            sliderValue = sqrt(viewModel.echoVolume)
        }
    }
}

/*
 The fidelity slider value is interpreted as a fraction of the maximum fidelity kUserIFCurvePointCount
 */
struct FidelitySliderView: View {
    
    @ObservedObject var viewModel:GraphicalArrayModel
    
    @Environment(\.undoManager) var undoManager
    
    @State var isEditing = false
    @State var oldValue:Int = 0
    @State var sliderValue = Double(kUserIFCurvePointCount)
    
    var body: some View {
        VStack {
            HStack {
                Text("\(viewModel.fidelity)")
                    .monospacedDigit()
                
                Spacer() 
            }
            
            Slider(value: $sliderValue, in: 0...1, // sqrt(2)
                   onEditingChanged: { editing in
                isEditing = editing
                if editing == false {
                    viewModel.registerUndoForFidelitySlider(oldValue: oldValue, undoManager: undoManager)
                    viewModel.graphicalArrayDelegate?.graphicalArrayFidelityChanged()
                    oldValue = viewModel.fidelity
                }
            })
            .onChange(of: sliderValue) { new_fidelitySliderValue in
                viewModel.fidelity = Int(Double(kUserIFCurvePointCount) * pow(new_fidelitySliderValue, 2))
            }
        }
        .onChange(of: viewModel.fidelity) { new_fidelity in
            if new_fidelity != Int(Double(kUserIFCurvePointCount) * pow(sliderValue, 2)) {
                sliderValue = sqrt(Double(new_fidelity) / Double(kUserIFCurvePointCount))
            }
        }
        .onAppear {
            oldValue = viewModel.fidelity
            sliderValue = sqrt(Double(viewModel.fidelity) / Double(kUserIFCurvePointCount))
        }
        
    }
}

struct WaveTypePickerView: View {
    
    @ObservedObject var viewModel:GraphicalArrayModel
    
    @Environment(\.undoManager) var undoManager
    
    @State var oldValue: WaveFunctionType = .sine
    @State var pickerValue: WaveFunctionType = .sine
        
    var body: some View {
        HStack {
            Picker("", selection: $pickerValue) {
                ForEach(WaveFunctionType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .onChange(of: pickerValue) { new_pickerValue in
                if new_pickerValue != viewModel.componentType {
                    viewModel.componentType = new_pickerValue
                    viewModel.registerUndoForComponentTypePicker(oldValue: oldValue, undoManager: undoManager)
                    viewModel.graphicalArrayDelegate?.graphicalArrayComponentTypeChanged() 
                    oldValue = new_pickerValue
                }
            }
            .onChange(of: viewModel.componentType) { new_componentType in
                if new_componentType != pickerValue {
                    pickerValue = new_componentType
                    oldValue = new_componentType
                }
            }
            .frame(width:200)
            
            GeneratePath(a: 0, b: plotRange, period: 1, phaseOffset: 0, N: 1000, frameSize: plotSize, inset: plotInset, graph: unitFunction(viewModel.componentType))
                .stroke(plotLineColor, style: StrokeStyle(lineWidth: plotLineWidth, lineCap: .round, lineJoin: .round))
                .scaleEffect(CGSize(width: 0.9, height: 0.9))
                .frame(width: plotSize.width, height: plotSize.height)
                .customBorderStyle()
        }
        .onAppear {
            pickerValue = viewModel.componentType
            oldValue = viewModel.componentType
        }
    }
}

struct ScaleTypePickerView: View {
    
    @ObservedObject var viewModel:GraphicalArrayModel
    
    @Environment(\.undoManager) var undoManager
    
    @State var oldValue: ToneShaperScaleType = .sine
    @State var pickerValue: ToneShaperScaleType = .sine
    
    var body: some View {
        HStack {
            Picker("", selection: $pickerValue) {
                ForEach(ToneShaperScaleType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .onChange(of: pickerValue) { new_pickerValue in
                if new_pickerValue != viewModel.scaleType {
                    viewModel.scaleType = new_pickerValue
                    viewModel.registerUndoForScaleTypePicker(oldValue: oldValue, undoManager: undoManager)
                    viewModel.graphicalArrayDelegate?.graphicalArrayScaleTypeChanged() 
                    oldValue = new_pickerValue
                }
            }
            .onChange(of: viewModel.scaleType) { new_scaleType in
                if new_scaleType != pickerValue {
                    pickerValue = new_scaleType
                    oldValue = new_scaleType
                }
            }
            .frame(width:200)
            
            Image(viewModel.scaleType.rawValue)
                .resizable()
                .frame(width: plotSize.width, height: plotSize.height)
                .padding(2)
                .customBorderStyle()
        }
        .onAppear {
            pickerValue = viewModel.scaleType
            oldValue = viewModel.scaleType
        }
    }
}

let plotLineWidth:Double = 3.0
let plotRange = 1.0 // 2.0 for two cycles
let plotLineColor = Color(red: 0.0, green: 0.45, blue: 0.90)
let plotSize = CGSize(width: 48, height: 48)
let plotInset = 3.0

struct GraphicalArrayOptionsView: View {
    
    @ObservedObject var viewModel:GraphicalArrayModel
    
    let noteDiameter = 22.0
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        VStack(alignment: .leading) {
            
            VStack(alignment: .leading) {
            
                HStack {
                    Text("Amplitude Scale Type")
                        .bold()
                    
                    Button(action: {
                        let oldValue = viewModel.scaleType
                        viewModel.scaleType = kDefaultScaleType
                        viewModel.registerUndoForScaleTypePicker(oldValue: oldValue, undoManager: undoManager)
                        viewModel.graphicalArrayDelegate?.graphicalArrayScaleTypeChanged() 
                    }, label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(.black, .gray)
                        }
                    })
                }
                
                ScaleTypePickerView(viewModel: viewModel)
                
                Text(kAmplitudeScalingNote)
                    .font(.caption)
                
            }
            .padding()
            
            VStack(alignment: .leading) {
                
                HStack {
                    Text("Echo Offset")
                        .bold()
                    
                    Button(action: {
                        let oldValue = viewModel.echoOffsetTimeSeconds
                        viewModel.echoOffsetTimeSeconds = 0
                        viewModel.registerUndoForEchoOffsetSlider(oldValue: oldValue, undoManager: undoManager)
                        viewModel.graphicalArrayDelegate?.graphicalArrayEchoOffsetChanged()
                    }, label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(.black, .gray)
                        }
                    })
                }
                
                EchoOffsetSliderView(viewModel: viewModel)
                    .padding(EdgeInsets(top: 5, leading: 0, bottom: 0, trailing: 0))
        
            }
            .padding()
            
            VStack(alignment: .leading) {
                
                HStack {
                    Text("Echo Volume")
                        .bold()
                    
                    Button(action: {
                        let oldValue = viewModel.echoVolume
                        viewModel.echoVolume = 1
                        viewModel.registerUndoForEchoVolumeSlider(oldValue: oldValue, undoManager: undoManager)
                        viewModel.graphicalArrayDelegate?.graphicalArrayEchoVolumeChanged()
                    }, label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(.black, .gray)
                        }
                    })
                }
                
                EchoVolumeSliderView(viewModel: viewModel)
                .padding(EdgeInsets(top: 5, leading: 0, bottom: 0, trailing: 0))
            }
            .padding()
            
            VStack(alignment: .leading) {
                
                HStack {
                    Text("Fidelity")
                        .bold()
                    
                    Button(action: {
                        let oldValue = viewModel.fidelity
                        viewModel.fidelity = kUserIFCurvePointCount
                        viewModel.registerUndoForFidelitySlider(oldValue: oldValue, undoManager: undoManager)
                        viewModel.graphicalArrayDelegate?.graphicalArrayFidelityChanged()
                    }, label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(.black, .gray)
                        }
                    })
                }
                
                FidelitySliderView(viewModel: viewModel)
                    .padding(EdgeInsets(top: 5, leading: 0, bottom: 0, trailing: 0))
            }
            .padding()
            
            VStack(alignment: .leading) {
                
                HStack {
                    Text("Wave Type")
                        .bold()
                    
                    Button(action: {
                        let oldValue = viewModel.componentType
                        viewModel.componentType = kDefaultComponentType
                        viewModel.registerUndoForComponentTypePicker(oldValue: oldValue, undoManager: undoManager)
                        viewModel.graphicalArrayDelegate?.graphicalArrayComponentTypeChanged() 
                    }, label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(.black, .gray)
                        }
                    })
                }
                
                WaveTypePickerView(viewModel: viewModel)
                
                Text(kComponentTypeNote)
                    .font(.caption)
                
            }
            .padding()
            
            HStack {
                
                HStack {
                    Text("Label Type")
                        .bold()
                    
                    Button(action: {
                        viewModel.labelType = kDefaultLabelType
                    }, label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(.black, .gray)
                        }
                    })
                }
                
                Picker("", selection: $viewModel.labelType) {
                    ForEach(GAELabelType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .frame(width:200)
                
            }
            .padding()
            
                // option to turn off audio feedback during tapping or dragging
            VStack(alignment: .leading) {
                
                HStack {
                    Text("Audio Feedback")
                        .bold()
                    
                    Button(action: {
                        viewModel.speakerOn = true
                    }, label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(.black, .gray)
                        }
                    })
                }
                
                HStack {
                        // icon button
                    Button(action: {
                        viewModel.speakerOn = !viewModel.speakerOn
                    }, label: {
                        (viewModel.speakerOn ?  Image(systemName: "speaker") : Image(systemName: "speaker.slash"))
                    })
                    .customButtonStyle() 
                    
                        // text button
                    Button(action: {
                        viewModel.speakerOn = !viewModel.speakerOn
                    }, label: {
                        (viewModel.speakerOn ?  Text("On").foregroundColor(.green) : Text("Off").foregroundColor(.red))
                    })
                }
                
                Text(kAudioFeedbackNote)
                    .font(.caption)
            }
            .padding()
            
            VStack(alignment: .leading) {
                
                HStack {
                    Text("Highlight Notes")
                        .bold()
                    
                    Button(action: {
                        viewModel.highlightNotes = true
                    }, label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(.black, .gray)
                        }
                    })
                }
                
                HStack {
                        // icon button
                    Button(action: {
                        viewModel.highlightNotes = !viewModel.highlightNotes
                    }, label: {
                        Circle()
                            .fill(Color.black)
                            .frame(width: noteDiameter, height: noteDiameter)
                            .overlay(
                                Circle()
                                    .stroke(Color.green, lineWidth: viewModel.highlightNotes ? noteDiameter/4 : 0) 
                            )
                    })
                    .customButtonStyle() 
                    
                        // text button
                    Button(action: {
                        viewModel.highlightNotes = !viewModel.highlightNotes
                    }, label: {
                        (viewModel.highlightNotes ?  Text("On").foregroundColor(.green) : Text("Off").foregroundColor(.red))
                    })
                }
            }
            .padding()
        }
    }
}

struct GraphicalArrayOptionsView_ScrollingPrevew: View {
    
    
    var body: some View {
        ScrollView {
            GraphicalArrayOptionsView(viewModel: GraphicalArrayModel(data: kDefaultModelData))
        }
    }
}

#Preview("Options") {
    GraphicalArrayOptionsView_ScrollingPrevew()
}

#Preview("Echo Offset") {
    EchoOffsetSliderView(viewModel: GraphicalArrayModel(data: kDefaultModelData))
}

#Preview("Echo Volume") {
    EchoVolumeSliderView(viewModel: GraphicalArrayModel(data: kDefaultModelData))
}

#Preview("Fidelity") {
    FidelitySliderView(viewModel: GraphicalArrayModel(data: kDefaultModelData))
}

#Preview("Wave Type") {
    WaveTypePickerView(viewModel: GraphicalArrayModel(data: kDefaultModelData))
}

#Preview("Scale Type") {
    ScaleTypePickerView(viewModel: GraphicalArrayModel(data: kDefaultModelData))
}
