//
//  OctaveView.swift
//  TonePlayer
//
//  Created by Joseph Pagliaro on 2/20/23.
//

import SwiftUI

struct SelectedNoteView: View {
    
    @ObservedObject var viewModel:GraphicalArrayModel
    
    var body: some View {
        VStack {
                // Selected Note
            HStack {
                Image(systemName: "music.note")
                Text("Selected Note:")
            }
            
            if let selectedNoteFrequency = viewModel.selectedNoteFrequency {
                
                HStack {
                    Text("\(pianoNoteForFrequency(selectedNoteFrequency)) (\(String(format: "%.2f", selectedNoteFrequency)) Hz)")
                        .textSelection(.enabled)
                        .monospacedDigit()
                    
                    Button(action: {
                        viewModel.playAudioFrequency(selectedNoteFrequency)
                    }) {
                        Text("Play")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
            }
            else {
                Text("None")
            }
            
        }
    }
}

struct OctaveView: View {
    
    @ObservedObject var viewModel:GraphicalArrayModel
    
    @State var showFrequencies = true
    
    var headerView: some View {
        VStack {
            HStack {
                
                HStack {
                    Button(action: {
                        viewModel.isShowingOctaveView = false
                    }, label: {
                        Image(systemName: "x.circle")
                            .foregroundStyle(.red, .gray)
                    })
                    .customButtonStyle() 
                    
                    Text("Note Picker")
                }
                .padding()
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Toggle(isOn: $showFrequencies) {
                        
                    }
                    
                    Text("Show Frequencies")
                }
                .padding()
            }
            
            SelectedNoteView(viewModel: viewModel)
            
            ThrobbingText(text: "Frequency Range: \(String(format: kRangePrecisonDisplay, viewModel.minFrequency))...\(String(format: kRangePrecisonDisplay, viewModel.maxFrequency))", maxCycles: 7)
                .font(.caption)
        }
    }
    
    var body: some View {
        ScrollView {
            
            headerView
            
            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: viewModel.octaveViewColumnsCount), spacing: 10) {
                ForEach(viewModel.octavesArray.indices, id: \.self) { sectionIndex in
                    Section(header: Text("Octave \(sectionIndex)")) {
                        ForEach(viewModel.octavesArray[sectionIndex], id: \.note) { tuple in
                            Button(action: {
                                viewModel.onOctaveViewNoteTap(tuple.frequency)
                            }) {
                                if showFrequencies {
                                    VStack {
                                        Text(tuple.note)
                                        Text(String(format: "%.2f", tuple.frequency))
                                            .font(.caption)
                                    }
                                }
                                else {
                                    Text(tuple.note)
                                }
                            }
                            .disabled(tuple.frequency < viewModel.minFrequency || tuple.frequency > viewModel.maxFrequency)
#if os(macOS)
                            .foregroundColor(.blue) 
                            .buttonStyle(PlainButtonStyle())
#endif
                            //.overlay(viewModel.selectedNoteFrequency == tuple.frequency ? RoundedRectangle(cornerRadius: 6) .stroke(.red, lineWidth: 1) : nil)
                            .overlay(viewModel.selectedNoteFrequency.map { selectedFrequency in
                                return selectedFrequency == tuple.frequency ? RoundedRectangle(cornerRadius: 6).stroke(.red, lineWidth: 1) : nil
                            })

                        }
                    }
                }
            }
        }
        .background(Color.white)
    }
}

struct OctaveView_Previews: PreviewProvider {
    static var previews: some View {
        
        let viewModel = GraphicalArrayModel(data: kDefaultModelData)
        OctaveView(viewModel: viewModel)
    }
}


