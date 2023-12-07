//
//  GraphicalArraySelectionControlView.swift
//  ToneShaper
//
//  Created by Joseph Pagliaro on 9/29/23.
//

import SwiftUI

let frequencyDeltas:[Double] = [1000.0, 100.0, 10.0, 1.0, 0.1, 0.01]
let timeDeltas:[Double] = [1.0, 0.1, 0.01]

struct DisabledAndOpacityModifier: ViewModifier {
    let condition: Bool
    
    func body(content: Content) -> some View {
        content
            .disabled(condition)
            .opacity(condition ? 0.5 : 1.0)
    }
}

extension View {
    func disableIf(_ condition: Bool) -> some View {
        self.modifier(DisabledAndOpacityModifier(condition: condition))
    }
}

struct GraphicalArraySelectionControlView: View {
    
    @ObservedObject var viewModel:GraphicalArrayModel
    
    @State var deltaFrequency = 100.0
    @State var deltaTime = 1.0
        
    @State var selectedEqualizationType: EqualizationType = .average
    
    @Environment(\.undoManager) var undoManager
        
    var body: some View {
        VStack(alignment: .leading) {
            
            // Delete selection
            HStack {
                
                Text("Delete")
                    .bold()
                
                    // delete selected points
                Button(action: {
                    viewModel.deleteSelectedPoints(undoManager: undoManager)
                    viewModel.graphicalArrayDelegate?.graphicalArrayPointsDeleted()
                }, label: {
                    HStack {
                        Image(systemName: "minus.rectangle")
                            .foregroundStyle(.red, .gray)
                    }
                })
                .customButtonStyle() 
                
                Text("Set Note")
                    .bold()
                    .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 0))
                
                Button(action: {
                    
                    viewModel.selectedNoteFrequency = nil
                    
                        // set the note tap action
                    viewModel.onOctaveViewNoteTap = { frequency in
                    
                        viewModel.selectedNoteFrequency = frequency
                        viewModel.playAudioFrequency(frequency)
                        
                            // apply selected note as in `Apply Note to Selection`
                        if viewModel.equalizeSelection(EqualizationType.selectedNote, undoManager: undoManager) {
                            viewModel.graphicalArrayDelegate?.graphicalArraySelectionFrequencyChanged()
                        }
                    }
                    viewModel.isShowingOctaveView = true
                    
                }, label: {
                    Image(systemName: "music.note")
                        .foregroundStyle(.red, .gray)
                })

            }
            .disableIf(viewModel.selectedPointIndices.isEmpty)
            
            // Select all or none
            HStack {
                Text("Select")
                    .bold()
                
                    // Select all
                Button(action: {
                    viewModel.selectAll()
                }) {
                    Text("All (\(viewModel.points.count))")
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                    // Select none
                Button(action: {
                    viewModel.unselectAll()
                }, label: {
                    HStack {
                        Text("None")
                            .foregroundColor(.blue)
                        Image(systemName: "circle.slash")
                            .foregroundStyle(.red, .gray)
                    }
                })
            }
            
            // Increment or decrement times of selection
            VStack(alignment: .leading) {
                HStack {
                    
                    Text("Time")
                        .bold()
                    
                    Button(action: {
                        if viewModel.decrementTime(deltaTime, selectedPointIndices: viewModel.selectedPointIndices, undoManager: undoManager) {
                            viewModel.graphicalArrayDelegate?.graphicalArraySelectionTimeChanged()
                        }
                        else {
                            DispatchQueue.main.async {
                                viewModel.alertInfo = GAAlertInfo(id: .canNotApply, title: "Decrement Time", message: "The points time could not be decremented possibly because the limit has been reached.", action: {
                                    
                                })
                            }
                        }
                    }, label: {
                        Image(systemName: "minus.square")
                            .foregroundStyle(.red, .gray)
                    })
                    .customButtonStyle() 
                    
                    Button(action: {
                        if viewModel.incrementTime(deltaTime, selectedPointIndices: viewModel.selectedPointIndices, undoManager: undoManager) {
                            viewModel.graphicalArrayDelegate?.graphicalArraySelectionTimeChanged()
                        }
                        else {
                            DispatchQueue.main.async {
                                viewModel.alertInfo = GAAlertInfo(id: .canNotApply, title: "Increment Time", message: "The points time could not be incremented possibly because the limit has been reached.", action: {
                                    
                                })
                            }
                        }
                    }, label: {
                        Image(systemName: "plus.square")
                            .foregroundStyle(.red, .gray)
                    })
                    .customButtonStyle() 
                    
                    Picker("", selection: $deltaTime) {
                        ForEach(timeDeltas, id: \.self) { value in
                            Text(String(value))
                        }
                    }
                    .frame(width: 100)
                    
                }
                
                
                Text("Times are limited by neighbors, and duration set below")
                    .font(.caption)
            }
            .disableIf(viewModel.selectedPointIndices.isEmpty)
            
            
            VStack(alignment: .leading) {
                
                // Increment or decrement frequency of selection
                HStack {
                    Text("Frequency")
                        .bold()
                    
                    Button(action: {
                        if viewModel.decrementFrequency(deltaFrequency, selectedPointIndices: viewModel.selectedPointIndices, undoManager: undoManager) {
                            viewModel.graphicalArrayDelegate?.graphicalArraySelectionFrequencyChanged()
                        }
                        else {
                            DispatchQueue.main.async {
                                viewModel.alertInfo = GAAlertInfo(id: .canNotApply, title: "Decrement Frequency", message: "The points frequency could not be decremented possibly because the limit has been reached.", action: {
                                    
                                })
                            }
                        }
                    }, label: {
                        Image(systemName: "minus.square")
                            .foregroundStyle(.red, .gray)
                    })
                    .customButtonStyle() 
                    
                    Button(action: {
                        if viewModel.incrementFrequency(deltaFrequency, selectedPointIndices: viewModel.selectedPointIndices, undoManager: undoManager) {
                            viewModel.graphicalArrayDelegate?.graphicalArraySelectionFrequencyChanged()
                        }
                        else {
                            DispatchQueue.main.async {
                                viewModel.alertInfo = GAAlertInfo(id: .canNotApply, title: "Increment Frequency", message: "The points frequency could not be incremented possibly because the limit has been reached.", action: {
                                    
                                })
                            }
                        }
                    }, label: {
                        Image(systemName: "plus.square")
                            .foregroundStyle(.red, .gray)
                    })
                    .customButtonStyle() 
                    
                    Picker("", selection: $deltaFrequency) {
                        ForEach(frequencyDeltas, id: \.self) { value in
                            Text(String(value))
                        }
                    }
                    .frame(width: 100)
                }
                .disableIf(viewModel.selectedPointIndices.isEmpty)
                
                Text("Frequency is limited to range set below")
                    .font(.caption)
            }
            
            // move the selection 
            HStack {
                Text("Move")
                    .bold()
                
                Button(action: {
                    viewModel.moveSelectionLeft()
                }, label: {
                    Image(systemName: "chevron.left")
                })
                .customButtonStyle() 
                .padding(.horizontal)  
                
                Button(action: {
                    viewModel.moveSelectionRight()
                }, label: {
                    Image(systemName: "chevron.right")
                })
                .customButtonStyle() 
                
            }
            .disableIf(viewModel.selectedPointIndices.isEmpty)
            
            // equalize the selection 
            HStack {
                Text("Equalize")
                    .bold()
                
                Picker("", selection: $selectedEqualizationType) {
                    ForEach(EqualizationType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .frame(width:150)
                .onChange(of: selectedEqualizationType) { newValue in
                    if newValue == EqualizationType.selectedNote, viewModel.selectedNoteFrequency == nil {
                        viewModel.alertInfo = GAAlertInfo(id: .canNotApply, title: "No Selected Note", message: "There is no selected note. Set the selected note in the Note Editor.", action: {
                            
                        })
                    }
                }
                
                Button(action: {
                    if viewModel.equalizeSelection(selectedEqualizationType, undoManager: undoManager) {
                        viewModel.graphicalArrayDelegate?.graphicalArraySelectionFrequencyChanged()
                    }
                    
                    if selectedEqualizationType == EqualizationType.selectedNote, viewModel.selectedNoteFrequency == nil {
                        viewModel.alertInfo = GAAlertInfo(id: .canNotApply, title: "No Selected Note", message: "There is no selected note. Set the selected note in the Note Editor.", action: {
                            
                        })
                    }
                }, label: {
                    Image(systemName: "equal.square")
                        .foregroundStyle(.red, .gray)
                })
                .customButtonStyle() 
            }
            .disableIf(viewModel.selectedPointIndices.isEmpty)
            
            HStack {
                Text("Closest Note")
                    .bold()
                
                Button(action: {
                    if viewModel.replacePointsFrequencyWithClosestNoteFrequency(undoManager: undoManager) {
                        viewModel.graphicalArrayDelegate?.graphicalArraySelectionFrequencyChanged()
                    }
                }, label: {
                    Image(systemName: "arrow.up.to.line.compact")
                        .foregroundStyle(.red, .gray)
                })
                .customButtonStyle() 
                
            }
            .disableIf(viewModel.selectedPointIndices.isEmpty)
            
            // play or export audio of the selection
            HStack {
                
                Text("Play")
                    .bold()
                
                    // play all selected points
                Button(action: {
                    viewModel.playAudioSelectedIndices()
                }, label: {
                    Image(systemName: "play.circle")
                        .foregroundStyle(.green, .gray)
                })
                .customButtonStyle() 
                
                    // stop any audio play
                Button(action: {
                    viewModel.stopAudioPlayer()
                }, label: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.red, .gray)
                })
                .customButtonStyle() 
                
                    // At least 2 selected points required
                Button(action: {
                    viewModel.exportSelectedToneSequenceAudio {
                        DispatchQueue.main.async {
                            viewModel.alertInfo = GAAlertInfo(id: .exporterFailed, title: "Audio Not Exported", message: "Tone sequence audio could not be exported.", action: {})
                        }
                    }
                }, label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.green, .gray)
                    }
                })
                .customButtonStyle() 
                
                    // the tone duratone of each point frequency 
                Picker("", selection: $viewModel.componentDuration) {
                    ForEach(componentDurations, id: \.self) { value in
                        Text("\(String(format: "%.1f", value))")
                    }
                }
                .frame(width: 70)
                
            }
            .disableIf(viewModel.selectedPointIndices.isEmpty)
            
        }
    }
}

struct GraphicalArraySelectionControlView_Previews: PreviewProvider {
    static var previews: some View {
        GraphicalArraySelectionControlView(viewModel: GraphicalArrayModel(data: kDefaultModelData))
    }
}
