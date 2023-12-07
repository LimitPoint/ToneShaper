//
//  GraphicalArrayNotePickerView.swift
//  ToneShaper
//
//  Created by Joseph Pagliaro on 10/19/23.
//

import SwiftUI

struct GraphicalArrayNotePickerView: View {
    @ObservedObject var viewModel:GraphicalArrayModel
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        VStack(alignment: .leading) {
            
                // These sets are used for logic
            let frequencyRange = viewModel.minFrequency...viewModel.maxFrequency
            
            let pointsWithSelectedNoteFrequency = viewModel.pointsWithSelectedNoteFrequency()
            
            let selectedPointsWithSelectedNoteFrequency = viewModel.selectedPointIndices.intersection(pointsWithSelectedNoteFrequency)
            
            let allSelectedPointsHaveSelectedNoteFrequency = viewModel.selectedPointIndices.isSubset(of: selectedPointsWithSelectedNoteFrequency)
            
            let selectedPointsNoteFrequency:Double? = viewModel.selectedPointsNoteFrequency() 
            
            Group {
                
                    // Edit Note of Selection
                Button(action: {
                    if let selectedPointsNoteFrequency = selectedPointsNoteFrequency {
                        
                            // initialize the selected note
                        viewModel.selectedNoteFrequency = selectedPointsNoteFrequency
                        
                            // set the note tap action
                        viewModel.onOctaveViewNoteTap = { frequency in
                            
                                // updated selected note
                            viewModel.selectedNoteFrequency = frequency
                            viewModel.playAudioFrequency(frequency)
                            
                                // apply selected note as in `Apply Note to Selection`
                            if viewModel.equalizeSelection(EqualizationType.selectedNote, undoManager: undoManager) {
                                viewModel.graphicalArrayDelegate?.graphicalArraySelectionFrequencyChanged()
                            }
                        }
                        viewModel.isShowingOctaveView = true
                    }
                }, label: {
                    HStack {
                        Text("Edit Note of Selection")
                            .foregroundColor(.red)
                    }
                })
                .disableIf(selectedPointsNoteFrequency == nil) // no points have the selected frequency
                
                if selectedPointsNoteFrequency == nil {
                    Text("The selected points do not all have the same note frequency.")
                        .font(.caption)
                }
                
                Divider()
                
                SelectedNoteView(viewModel: viewModel)
                 
                    // Select Note
                Button(action: {
                    viewModel.onOctaveViewNoteTap = { frequency in
                        viewModel.selectedNoteFrequency = frequency
                        viewModel.playAudioFrequency(frequency)
                    }
                    viewModel.isShowingOctaveView = true
                }, label: {
                    HStack {
                        Text("Select Note")
                            .foregroundColor(.blue)
                    }
                })
                
                    // Apply Note to Selection
                if let selectedNoteFrequency = viewModel.selectedNoteFrequency {
                    
                    let selectedNoteInRange = frequencyRange.contains(selectedNoteFrequency)
                    
                    Button(action: {
                        if viewModel.equalizeSelection(EqualizationType.selectedNote, undoManager: undoManager) {
                            viewModel.graphicalArrayDelegate?.graphicalArraySelectionFrequencyChanged()
                        }
                    }, label: {
                        HStack {
                            Text("Apply Selected Note to Selection")
                                .foregroundColor(.red)
                        }
                    })
                    .disableIf(viewModel.selectedPointIndices.isEmpty || selectedNoteInRange == false || allSelectedPointsHaveSelectedNoteFrequency)
                    
                    if viewModel.selectedPointIndices.isEmpty {
                        Text("There is no selection.")
                            .font(.caption)
                    }
                    else if selectedNoteInRange == false {
                        Text("To apply the selected note it must be in the current frequency range.")
                            .font(.caption)
                    }
                    else if allSelectedPointsHaveSelectedNoteFrequency {
                        Text("All selected points have the selected note frequency.")
                            .font(.caption)
                    }
                }
                else {
                    Text("There is no selected note.")
                        .font(.caption)
                }
                
                Divider()
                
                // Select Points With Selected Note
                Button(action: {
                    viewModel.selectedPointIndices = pointsWithSelectedNoteFrequency
                }, label: {
                    HStack {
                        Text("Select Points With Selected Note")
                            .foregroundColor(.red)
                    }
                })
                .disableIf(pointsWithSelectedNoteFrequency.isEmpty) // no points have the selected frequency
                
                if pointsWithSelectedNoteFrequency.isEmpty {
                    Text("None of the points have the selected note frequency.")
                        .font(.caption)
                }
                
                Divider()
                
                // Set Selected Note from Selected Points
                Button(action: {
                    if let selectedPointsNoteFrequency = selectedPointsNoteFrequency {
                        viewModel.selectedNoteFrequency = selectedPointsNoteFrequency
                    }
                }, label: {
                    HStack {
                        Text("Set Selected Note from Selected Points")
                            .foregroundColor(.red)
                    }
                })
                .disableIf(selectedPointsNoteFrequency == nil) // no points have the selected frequency
                
                if selectedPointsNoteFrequency == nil {
                    Text("The selection does not have a note frequency.")
                        .font(.caption)
                }
                
            }
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 5, trailing: 10))
        }
    }
}

#Preview("NotePickerView") {
    GraphicalArrayNotePickerView(viewModel: GraphicalArrayModel(data: kDefaultModelData))
}
