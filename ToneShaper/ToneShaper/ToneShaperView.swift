//
//  ToneShaperView.swift
//  ToneShaper
//
//  Created by Joseph Pagliaro on 9/15/23.
//

import SwiftUI

struct PlayButton: View {
    
    @ObservedObject var toneShaperDocument:ToneShaperDocument 
    
    var body: some View {
        Group {
            if toneShaperDocument.audioEngineManager.isPlaying {
                Button {
                    toneShaperDocument.audioEngineManager.stopPlaying {
                        
                    }
                } label: {
                    Image(systemName: "stop.circle")
                        .foregroundStyle(.red, .gray)
                }
            }
            else {
                Button {
                    toneShaperDocument.audioEngineManager.startPlaying { success in
                        if success {
                            
                        }
                    }
                } label: {
                    Image(systemName: "play.circle")
                        .foregroundStyle(.green, .gray)
                    
                }
            }
        }
        .customButtonStyle()
        
    }
}

func ShouldShowSplashScreen() -> Bool {
    if UserDefaults.standard.object(forKey: shouldShowSplashScreenKey) != nil {
        return UserDefaults.standard.bool(forKey: shouldShowSplashScreenKey)
    } 
    
    return true
}

struct ToneShaperView: View {
    
    @Binding var showSplashScreen:Bool
    
    @ObservedObject var toneShaperDocument:ToneShaperDocument
    
    @ObservedObject var webViewObservable: WebViewObservableObject
    
    @State var isShowingSamples = false

    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        
        VStack {
            
            if isShowingSamples {          
                SamplesView(isShowingSamples: $isShowingSamples, selectedSample: { sampleURL in 
                    toneShaperDocument.graphicalArrayModel.alertInfo = GAAlertInfo(id: .applySample, title: "Apply Sample", message: "Are you sure you want to apply the data from the selected sample?\n\nAll parameters are subject to change (Duration, frequency range, amplitude scale, echo offset, wave type, etc).", action: { 
                        toneShaperDocument.graphicalArrayModel.loadModelDataFromURL(fileURL: sampleURL, undoManager: undoManager)
                        toneShaperDocument.graphicalArrayDataLoaded()
                    })
                })
            }
            else if webViewObservable.isWebViewPresented {
                WebView(webViewModel: webViewObservable)
            }
            else {
                ZStack {
                    VStack {
                        HStack {
                            Button(action: {
                                isShowingSamples = true
                            }, label: {
                                Image(systemName: "building.columns")
                                    .foregroundStyle(.blue, .gray)
                            })
                            .customButtonStyle()
                            
                            Spacer()
                            
                            PlayButton(toneShaperDocument: toneShaperDocument)
                            
                            Spacer()
                            
                            UndoRedoButtonsView(toneShaperDocument: toneShaperDocument)
                                .customButtonStyle()
                            
                            Spacer()
                            
                            Button(action: {
                                webViewObservable.isWebViewPresented = true
                            }, label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.blue, .gray)
                            })
                            .customButtonStyle()
                        }
                        .padding(.horizontal)
                        
                        GraphicalArrayView(viewModel: toneShaperDocument.graphicalArrayModel)
                            .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                    }
                    
                    if showSplashScreen && ShouldShowSplashScreen() {
                        SplashScreenView(showSplashScreen: $showSplashScreen)
                    }
                }
                
            }
        }
        .onChange(of: toneShaperDocument) { newToneShaperDocument in
            /*
             
             WORKAROUND
             
             For issue: Feedback Assistent report FB13336463. ReferenceFileDocument is not released when using menu item `File > Revert > Browse All Versions`
             
             The problem: Create and revert a ReferenceFileDocument on macOS. Expect the original ReferenceFileDocument to be released and it is not. The reverted document however is released if it is reverted itself.
             
             This problem was discovered here but can be exhibited by running the Apple sample code BuildingADocumentBasedAppWithSwiftUI at https://developer.apple.com/documentation/swiftui/building_a_document-based_app_with_swiftui. 
             
             To reproduce - After reverting search log for 
             
                `ToneShaperDocument deinit <id>`
             
             Where `id` is that of the original replaced document printed from here
             
             */
            print("Document: \(toneShaperDocument.id), replaced with document \(newToneShaperDocument.id)")
            
            DispatchQueue.main.async {
                if toneShaperDocument.audioEngineManager.isPlaying {
                    toneShaperDocument.audioEngineManager.stopPlaying { 
                        newToneShaperDocument.audioEngineManager.startPlaying { success in
                            if success {
                                
                            }
                        }
                    }
                }
            }
        }
#if os(iOS)
        .navigationBarHidden(false)
#endif
#if os(macOS) 
        .onChange(of: toneShaperDocument.audioEngineManager.audioEngineConfigurationChangeCount) { _ in
            DispatchQueue.main.async {
                if toneShaperDocument.audioEngineManager.isPlaying {
                    toneShaperDocument.audioEngineManager.stopPlaying { 
                        toneShaperDocument.audioEngineManager.startPlaying { success in
                            if success {
                                
                            }
                        }
                    }
                }
            }
        }
#endif
#if os(iOS) 
        .onChange(of: toneShaperDocument.audioEngineManager.shouldStopPlaying) { shouldStopPlaying in
            
            if shouldStopPlaying == true {
                DispatchQueue.main.async {
                    toneShaperDocument.audioEngineManager.shouldStopPlaying = false
                    toneShaperDocument.audioEngineManager.stopPlaying { 
                        
                    }
                }
            }
        }
        .onChange(of: toneShaperDocument.audioEngineManager.shouldStartPlaying) { shouldStartPlaying in
            
            if shouldStartPlaying == true {
                DispatchQueue.main.async {
                    toneShaperDocument.audioEngineManager.shouldStartPlaying = false
                    toneShaperDocument.audioEngineManager.startPlaying { success in
                        if success {
                            
                        }
                    }
                }
            }
        }  
#endif
    }
}

struct ToneShaperView_Previews: PreviewProvider {
    static var previews: some View {
        ToneShaperView(showSplashScreen: .constant(false), toneShaperDocument: ToneShaperDocument(), webViewObservable: WebViewObservableObject(urlString: "https://www.limit-point.com"))
#if os(macOS)
            .frame(width: 600, height: 800)
#endif
    }
}
