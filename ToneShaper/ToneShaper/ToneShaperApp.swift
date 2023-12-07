//
//  ToneShaperApp.swift
//  ToneShaper
//
//  Created by Joseph Pagliaro on 7/28/23.
//

import SwiftUI
import AVFoundation

struct HelpMenu: View {
    var body: some View {
        Group {

            Link("Limit Point LLC", destination: URL(
                string: limitPointURL)!)
            Divider() 
            Link("ToneShaper Help", destination: URL(
                string: helpURL)!)
            
        }
    }
}

@main
struct ToneShaperApp: App {
        
    @State var showSplashScreen = true
        
#if os(iOS)    
    var audioSessionObserver: Any!
#endif
    
    init() {
        
        // run this to clear the shouldShowSplashScreenKey key 
        //UserDefaults.standard.removeObject(forKey: shouldShowSplashScreenKey)
    
#if os(iOS)         
        func setUpAudioSession() {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            } catch {
                print("Failed to set audio session route sharing policy: \(error.localizedDescription)")
            }
            
            print("Configured audio session")
        }
        
        let notificationCenter = NotificationCenter.default
        
        audioSessionObserver = notificationCenter.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: nil) { _ in
            setUpAudioSession()
        }
        
        setUpAudioSession()
#endif
    }
    
    var body: some Scene {
        DocumentGroup(newDocument: { ToneShaperDocument() }) { configuration in
            ToneShaperView(showSplashScreen: $showSplashScreen, toneShaperDocument: configuration.document, webViewObservable: WebViewObservableObject(urlString: helpURL))
                .preferredColorScheme(.light)
                .onAppear {
                    configuration.document.fileURL = configuration.fileURL // fileURL used for export default filename
                }
                .onChange(of: configuration.fileURL) { newFileURL in
                    configuration.document.fileURL = newFileURL // executes on Mac when saving new document
                }
        }
#if os(macOS)
        .defaultSize(width: 600, height: 800)
        .commands {
            CommandGroup(replacing: .help) {
                HelpMenu()
            }
        }
#endif
    }
}
