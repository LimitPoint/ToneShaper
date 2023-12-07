//
//  SplashScreenView.swift
//  Epicycles
//
//  Created by Joseph Pagliaro on 6/27/23.
//

import SwiftUI

// UserDefaults.standard.removeObject(forKey: shouldShowSplashScreenKey)
let shouldShowSplashScreenKey = "ShouldShowSplashScreen"

struct SplashScreenView: View {
    @Binding var showSplashScreen: Bool
    
    @State var fileURL:URL?
    
    var body: some View {
        ZStack {
            Color.white
                .cornerRadius(10)
                .shadow(radius: 10)
            
            VStack {
                
                if let fileURL = fileURL {
                    PlatformImageView(fileURL: fileURL, size: CGSize(width: samplesImageSize * 2, height: samplesImageSize * 2))
                        .frame(width: samplesImageSize, height: samplesImageSize) 
                        .padding(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0))
                }
                
                ScrollView {
                    VStack {
                        
                        Text("Volume Alert & Tips")
                            .padding(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0))
                            .foregroundColor(.red)
                        
                        Text(kSplashScreenText)
                            .font(.system(size: 12))
                            .padding(EdgeInsets(top: 5, leading: 10, bottom: 20, trailing: 10))
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)
                    }
                    
                }
                .background(Color.white)
                .border(subtleMistColor)
                .padding()
                
                Button("Dismiss") {
                    showSplashScreen = false
                }
                .foregroundColor(.blue)
                
                .buttonStyle(PlainButtonStyle())
                
                Button("Do Not Show Again") {
                        // Set the UserDefaults flag to false
                    UserDefaults.standard.set(false, forKey: shouldShowSplashScreenKey)
                    showSplashScreen = false
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.vertical)
                .buttonStyle(PlainButtonStyle())
            }
            .background(paleSkyBlueColor)
            .cornerRadius(10)
        }
        .frame(width:300, height:500)
        .onAppear {
            let fileURLs = FileManager.pathsForFilesInResourceFolderSortedByName(resourceFolderName: "Samples", fileExtension: "toneshaper")
            
            fileURL = fileURLs.randomElement()
        }

    }
}

struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView(showSplashScreen: .constant(true))
    }
}
