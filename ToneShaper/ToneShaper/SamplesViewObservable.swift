//
//  SamplesViewObservable.swift
//  ToneShaper
//
//  Created by Joseph Pagliaro on 11/4/23.
//

import SwiftUI
import Combine

class SamplesViewObservable: ObservableObject, AudioPlayerDelegate {
    
    @Published var toneShaperDocumentURLs: [URL] = []
    @Published var audioPlayIndex: Int?
    @Published var audioPlayProgress: [Double] = []
    
    let piToneWriter = PiecewiseIntegratorToneWriter()
    
    var audioPlayer:AudioPlayer
    @Published var isPreparingToPlay = false
    
    var cancelBag = Set<AnyCancellable>()
    
    init() {
        audioPlayer = AudioPlayer()
        audioPlayer.delegate = self
        
        $audioPlayIndex.sink { [weak self] newAudioPlayIndex in
            if let audioPlayIndex = self?.audioPlayIndex {
                self?.audioPlayProgress[audioPlayIndex] = 0 // zero the current progress bar before switch to next progress bar
            }
        }
        .store(in: &cancelBag)
    }
    
    deinit {
        print("SamplesViewObservable deinit")
    }
    
    func playToneShaperDocumentURL(_ fileURL:URL, duration:Double, loopCount: Int) {
        
        guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
            return
        }
        
        guard let data: Data = try? Data.init(contentsOf: fileURL, options: [.uncached]) else {
            return
        }
        
        guard let graphicalArrayModelData = try? JSONDecoder().decode(GraphicalArrayModelData.self, from: data) else {
            return
        }
        
        isPreparingToPlay = true
        
            // set options from data
        var echoOffsetTimeSeconds:Double = 0
        var echoVolume:Double = 1
        var scaleType = kDefaultScaleType
        var componentType = kDefaultComponentType
        var fidelity = kUserIFCurvePointCount
        
        SetProperties(from: graphicalArrayModelData, echoOffsetTimeSeconds: &echoOffsetTimeSeconds, echoVolume: &echoVolume, scaleType: &scaleType, componentType: &componentType, fidelity: &fidelity)
        
        let userIFCurve = GraphicalArrayModel.userIFCurve(fidelity, points: graphicalArrayModelData.points)
        
        generateToneShapeAudio(userIFCurve: userIFCurve, toneShaperScaleType: scaleType, duration: duration, loopCount: loopCount, echoOffsetTimeSeconds: echoOffsetTimeSeconds, echoVolume: echoVolume, componentType: componentType) { [weak self] url in
            
            guard let self = self else {
                return
            }
            
            DispatchQueue.main.async {
                self.isPreparingToPlay = false
            }
            
            if let url = url {
                let _ = audioPlayer.playAudioURL(url)
            }
        }
    }
    
    func generateToneShapeAudio(userIFCurve: [CGPoint], toneShaperScaleType:ToneShaperScaleType, duration:Double, loopCount: Int, echoOffsetTimeSeconds: Double, echoVolume: Double, componentType: WaveFunctionType, completion: @escaping (URL?) -> ()) {
        
        DispatchQueue.global().async { [weak self] in
            
            guard let self = self else {
                completion(nil)
                return
            }
            
            guard let outputURL = FileManager.documentsURL(filename: kGAEAudioExportName, subdirectoryName: kGAETemporarySubdirectoryName) else {
                completion(nil)
                return
            }
            
            piToneWriter.scale = toneShaperScale(toneShaperScaleType: toneShaperScaleType, duration: duration) // scale is applied over the duration of the tone shape
            
            piToneWriter.saveUserIFCurveSamplesToFile(userIFCurve: userIFCurve, curveDuration: duration, fileDuration: Double(loopCount) * duration, echoOffsetTimeSeconds: echoOffsetTimeSeconds, echoVolume: echoVolume,  destinationURL: outputURL, componentType: componentType) { url, message in
                
                if let message = message {
                    print(message)
                }
                
                self.piToneWriter.scale = nil // practice to prevent retain cycle
                
                completion(url)
            }
        }
    }
    
    func playSample(sampleURL:URL, duration: Double, loopCount:Int)  {
        
        stopPlaySample()
        
        self.audioPlayIndex = toneShaperDocumentURLs.firstIndex(of: sampleURL)
        
        DispatchQueue.main.async { [weak self] in
            self?.playToneShaperDocumentURL(sampleURL, duration: duration, loopCount: loopCount)
        }
    }
    
    func stopPlaySample() {
        audioPlayer.stopPlayingAudio()
    }
    
    func audioPlayProgress(_ player: AudioPlayer?, percent: CGFloat) {
        if let audioPlayIndex = self.audioPlayIndex {
            self.audioPlayProgress[audioPlayIndex] = max(min(percent, 1.0), 0) // set the current progress bar to the percent progress
        }
    }
    
    func audioPlayDone(_ player: AudioPlayer?, percent: CGFloat) {
        if let audioPlayIndex = self.audioPlayIndex {
            self.audioPlayProgress[audioPlayIndex] = 0 // zero the current progress bar 
        }
    }
}
