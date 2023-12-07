//
//  GraphicalArraySelectionControlView.swift
//  ToneShaper
//
//  Created by Joseph Pagliaro on 9/29/23.
//

import SwiftUI


struct GraphicalArrayExportView: View {
    
    @ObservedObject var viewModel:GraphicalArrayModel
    
    var body: some View {
        
        VStack(alignment: .leading) {
            HStack {
                
                Text("Preview")
                    .bold()
                
                Button(action: {
                    viewModel.playToneShape()
                }, label: {
                    HStack {
                        Image(systemName: "play.circle")
                            .foregroundStyle(.green, .gray)
                    }
                })
                .customButtonStyle() 
                
                VStack{
                    Picker("", selection: $viewModel.loopCount) {
                        ForEach(1...viewModel.maxLoopCount, id: \.self) { value in
                            Text("\(value)")
                        }
                    }
                    .pickerStyle(DefaultPickerStyle())
                    .frame(width:75)
                    
                    Text("Cycles (\(viewModel.loopCount))")
                        .font(.caption)
                }
                
                    // stop any audio play
                Button(action: {
                    viewModel.stopAudioPlayer()
                }, label: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.red, .gray)
                })
                .customButtonStyle() 
                
            }
            
            PlotAudioWaveformView(plotAudioObservable: viewModel.plotAudioObservable)
            
            HStack {
                Text("\(viewModel.plotAudioObservable.currentTimeString())")
                    .monospacedDigit()
                
                Text("(Drag over cycles)")
                    .font(.caption2)
            }
            
            
            HStack {
                
                Text("Audio To Files")
                    .bold()
                
                Button(action: {
                    viewModel.exportToneShapeAudio{
                        viewModel.alertInfo = GAAlertInfo(id: .exporterFailed, title: "Audio Not Exported", message: "Tone shape audio could not be exported.", action: {})
                    }
                }, label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.green, .gray)
                    }
                })
                .customButtonStyle() 
                
                Text("(Cycles up to \(Int(durationRange.upperBound)) s)")
                    .font(.caption2)
            }
            
            HStack {
                
                Text("Image To Photos")
                    .bold()
                
                Button(action: {
                    viewModel.saveToneShapeImageToPhotos() { success in
                        
                        DispatchQueue.main.async {
                            if success {
                                viewModel.alertInfo = GAAlertInfo(id: .imageSavedToPhotos, title: "Image Saved", message: "An image of the tone shape was saved to photos.", action: {})
                            }
                            else {
                                viewModel.alertInfo = GAAlertInfo(id: .imageNotSavedToPhotos, title: "Image Not Saved", message: "An image of the tone shape could not be saved to photos.", action: {})
                            }
                        }
                        
                    }
                }, label: {
                    VStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.green, .gray)
                    }
                })
                .customButtonStyle() 
            }
        }
    }
}

struct GraphicalArrayExportView_Previews: PreviewProvider {
    static var previews: some View {
        GraphicalArrayExportView(viewModel: GraphicalArrayModel(data: kDefaultModelData))
    }
}
