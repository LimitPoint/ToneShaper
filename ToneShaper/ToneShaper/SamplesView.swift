//
//  SamplesView.swift
//  ToneShaper
//
//  Created by Joseph Pagliaro on 9/30/23.
//

import SwiftUI

let samplesImageSize:CGFloat = 96
let samplesSpacing:CGFloat = 16

func cgImageForURL(fileURL: URL, size: CGSize) -> CGImage? {
    return GraphicalArrayModelDataCGImageForURL(fileURL: fileURL, size: size, scale: 1, inset: 10, labelType: .none)
}

struct PlatformImageView: View {
    let fileURL: URL
    
    let size: CGSize
    
    var body: some View {
        if let cgImage = cgImageForURL(fileURL: fileURL, size: size) {
#if os(macOS)
            Image(nsImage: NSImage(cgImage: cgImage, size: .zero))
                .resizable()
                .aspectRatio(contentMode: .fit)
#else
            Image(uiImage: UIImage(cgImage: cgImage))
                .resizable()
                .aspectRatio(contentMode: .fit)
#endif
        }
        else {
            Image(systemName: "exclamationmark.triangle.fill") // Example placeholder image
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}

struct SampleViewItem: View {
    
    @ObservedObject var samplesViewObservable:SamplesViewObservable
    
    let toneShaperDocumentURL:URL
    @Binding var isShowingSamples: Bool
    @Binding var loopCount: Int
    var selectedSample: ((_ sampleURL:URL) -> Void)
    
    @State var minFrequency: CGFloat = 0
    @State var maxFrequency: CGFloat = 0
    @State var duration: CGFloat = 0.0
    
    var body: some View {
        VStack(alignment: .leading) {
            
            Text("\(toneShaperDocumentURL.deletingPathExtension().lastPathComponent)")
                .font(.system(size: 20, weight: .light))
            
            VStack(alignment: .leading) {
                Text("\(String(format: kRangePrecisonDisplay, minFrequency)) Hz")
                    .font(.caption)
                
                Text("\(String(format: kRangePrecisonDisplay, maxFrequency)) Hz")
                    .font(.caption)
                
                Text("\(duration, specifier: "%.2f") s")
                    .font(.caption)
            }
            
            Button(action: {
                isShowingSamples = false
                selectedSample(toneShaperDocumentURL)
            }) {
                PlatformImageView(fileURL: toneShaperDocumentURL, size: CGSize(width: samplesImageSize * 2, height: samplesImageSize * 2))
                    .frame(width: samplesImageSize, height: samplesImageSize) 
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack {
                Button(action: {
                    samplesViewObservable.playSample(sampleURL: toneShaperDocumentURL, duration: duration, loopCount: loopCount)
                }) {
                    HStack {
                        Image(systemName: "play.circle")
                            .foregroundStyle(.green, .gray)
                    }
                }
                .foregroundStyle(.white, .gray)
                .padding(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 20))
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    samplesViewObservable.stopPlaySample()
                }) {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.red, .gray)
                }
                .foregroundStyle(.white, .gray)
                .padding(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0))
                .buttonStyle(PlainButtonStyle())
            }
            
            if let ourIndex = samplesViewObservable.toneShaperDocumentURLs.firstIndex(of: toneShaperDocumentURL), let audioPlayIndex = samplesViewObservable.audioPlayIndex, ourIndex == audioPlayIndex {
                ProgressView(value: samplesViewObservable.audioPlayProgress[audioPlayIndex])
            }
            else {
                ProgressView(value: 0)
            }
            
        }
        .onAppear {
            if let graphicalArrayModelData = GraphicalArrayModelDataForURL(fileURL: toneShaperDocumentURL) {
                minFrequency = graphicalArrayModelData.minFrequency
                maxFrequency = graphicalArrayModelData.maxFrequency
                duration = graphicalArrayModelData.duration
            }
        }
    }
}

struct SamplesView: View {
    
    @StateObject var samplesViewObservable = SamplesViewObservable()
    
    @Binding var isShowingSamples: Bool
    @State var loopCount:Int = 5
    var selectedSample: ((URL) -> Void)
   
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    @State private var columns: [GridItem] = [GridItem(.flexible(), spacing: samplesSpacing)]
    
    var body: some View {
        
        VStack {
            
            HStack {
                Text("Select and preview samples")
                    .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
                    .font(.title2)
                
                Spacer() 
                
                Button(action: {
                    isShowingSamples = false
                }, label: {
                    Image(systemName: "x.circle")
                        .foregroundStyle(.red, .gray)
                })
                .customButtonStyle() 
            }
            
            HStack{
                
                Text("Play preview:")
                    .font(.caption)
                
                Picker("", selection: $loopCount) {
                    ForEach(1...13, id: \.self) { value in
                        Text("\(value)")
                    }
                }
                .pickerStyle(DefaultPickerStyle())
                .frame(width:75)
                
                Text("Cycles")
                    .font(.caption)
            }
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: samplesSpacing) {
                    ForEach(samplesViewObservable.toneShaperDocumentURLs, id: \.self) { url in
                        SampleViewItem(samplesViewObservable: samplesViewObservable, toneShaperDocumentURL: url, isShowingSamples: $isShowingSamples, loopCount: $loopCount, selectedSample: selectedSample)
                            .padding()
                            .customBorderStyle()
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            samplesViewObservable.toneShaperDocumentURLs = FileManager.pathsForFilesInResourceFolderSortedByName(resourceFolderName: "Samples", fileExtension: "toneshaper")
            samplesViewObservable.audioPlayProgress = Array(repeating: 0.0, count: samplesViewObservable.toneShaperDocumentURLs.count)
            calculateGridColumns()
        }
        .onChange(of: horizontalSizeClass, perform: { _ in
            calculateGridColumns()
        })
        .overlay(Group {
            if samplesViewObservable.isPreparingToPlay {          
                ProgressView("Preparing to play...")
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(livelyLavenderColor))
            }
        })
    }
    
    private func calculateGridColumns() {
        #if os(macOS)
        if let mainScreen = NSScreen.main {
            let screenSize = mainScreen.frame
            if screenSize.width < 600 {
                columns = [GridItem(.flexible(), spacing: samplesSpacing)]
            } else if screenSize.width < 1000 {
                columns = [GridItem(.adaptive(minimum: (samplesImageSize + samplesSpacing), maximum: screenSize.width / 2), spacing: samplesSpacing)]
            } else {
                columns = [GridItem(.adaptive(minimum: (samplesImageSize + samplesSpacing), maximum: screenSize.width / 3), spacing: samplesSpacing)]
            }
        }
        #else
        let screenSize = UIScreen.main.bounds.size
        let isCompactWidth = horizontalSizeClass == .compact
        let isCompactHeight = verticalSizeClass == .compact
        
        if isCompactWidth && isCompactHeight {
            columns = [GridItem(.flexible(), spacing: samplesSpacing)]
        } else if isCompactWidth && !isCompactHeight {
            columns = [GridItem(.adaptive(minimum: (samplesImageSize + samplesSpacing), maximum: screenSize.width), spacing: samplesSpacing)]
        } else {
            columns = [GridItem(.adaptive(minimum: (samplesImageSize + samplesSpacing), maximum: screenSize.width), spacing: samplesSpacing), GridItem(.adaptive(minimum: (samplesImageSize + samplesSpacing), maximum: screenSize.width), spacing: samplesSpacing)]
        }        
        #endif

    }
}

struct SamplesView_Previews: PreviewProvider {
    static var previews: some View {
        SamplesView(isShowingSamples: Binding.constant(true), selectedSample: {_ in}) 
    }
}

struct SampleViewItem_Previews: PreviewProvider {
    
    static var previews: some View {
        let url = FileManager.pathsForFilesInResourceFolderSortedByName(resourceFolderName: "Samples", fileExtension: "toneshaper")[0]
        
        SampleViewItem(samplesViewObservable: SamplesViewObservable(), toneShaperDocumentURL: url, isShowingSamples: Binding.constant(true), loopCount: Binding.constant(3), selectedSample: {_ in})
    }
}
