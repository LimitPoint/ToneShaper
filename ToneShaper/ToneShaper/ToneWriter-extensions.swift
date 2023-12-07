//
//  ToneWriter-extensions.swift
//  ToneShaper
//
//  Created by Joseph Pagliaro on 9/9/23.
//

import SwiftUI
import AVFoundation

/*
 Example:
 
 let v:[Int16] = [1, 62, 83, 14, 50, 4,  36, 81, 13, 24, 33, 74, 98, 201, 322, 5, 102]        
 let t = amplitudeZeroSamplesDown(v)
 print(t)
 
 Prints:
 
 [1, 58, 72, 11, 37, 2, 22, 45, 6, 10, 12, 23, 24, 37, 40, 0, 0]
 
 */
func amplitudeZeroSamplesDown(_ v:[Int16]) -> [Int16] {
    
    let length = v.count
    
    var result = v
    
    if length > 1 {
        
        let e = length-1
        
        let delta = 1.0 / (Double(e))
        
        for i in e-length+1...e {
            let scale = 1.0 - (Double(i - (e-length+1)) * delta)
            result[i] = Int16(scale * Double(v[i]))
        }
    }
    
    return result
}

/*
 Example:
 
 let v:[Int16] = [1, 62, 83, 14, 50, 4,  36, 81, 13, 24, 33, 74, 98, 201, 322, 5, 102] 
 let t = amplitudeZeroSamplesUp(v)
 print(t)
 
 Prints:
 
 [0, 3, 10, 2, 12, 1, 13, 35, 6, 13, 20, 50, 73, 163, 281, 4, 102]
 
 */
func amplitudeZeroSamplesUp(_ v:[Int16]) -> [Int16] {
    
    let length = v.count
    
    var result = v
    
    if length > 1 {
        
        let e = length-1
        
        let delta = 1.0 / (Double(e))
        
        for i in 0...e {
            let scale = Double(i) * delta
            result[i] = Int16(scale * Double(v[i]))
        }
    }
    
    return result
}

/*
 Example:
 
 let w:[Int16] = [44]
 let v:[Int16] = [1, 62, 83, 14, 50, 4,  36, 81, 13, 24, 33, 74, 98, 201, 322, 5, 102]
 let t = transitionAudioSamples(from: w, to: v)
 print(t)
 
 Prints:
 
 [44, 45, 48, 38, 45, 31, 41, 60, 28, 32, 37, 64, 84, 171, 287, 7, 102]
 
 */
func transitionAudioSamples(from w:[Int16], to v:[Int16]) -> [Int16] {
    var t = [Int16](repeating: 0, count: v.count)
    let N = v.count-1
    let lastW = w[w.count-1]
    for i in 0...N {
        let frac = Double(i) / Double(N)
        let x = Double(lastW) * (1 - frac) + Double(v[i]) * frac
        t[i] = Int16(x)
    }
    
    return t
}

func amplitudeZeroSamples_frontEndUp(_ samples:[Int16], scalingPercent:Int) -> [Int16] {
    
    let count = samples.count
    
    let percent = Double(scalingPercent)/100.0
    let length = Int(Double(count) * percent)
    let halfLength = length / 2
    
    guard halfLength > 0 else {
        return samples
    }
    
    var preSamples = Array(samples[0...halfLength-1])
    var lastSamples:[Int16] = []
    if halfLength <= (count-1) {
        lastSamples = Array(samples[halfLength...(count-1)])
    }
    
    preSamples = amplitudeZeroSamplesUp(preSamples)
    
    var joined = preSamples
    joined.append(contentsOf: lastSamples)
    
    return joined
}

func amplitudeZeroSamples_backEndDown(_ samples:[Int16], scalingPercent:Int) -> [Int16] {
    
    let count = samples.count
    
    let percent = Double(scalingPercent)/100.0
    let length = Int(Double(count) * percent)
    let halfLength = length / 2
    
    guard halfLength > 0 else {
        return samples
    }
    
    let startSamples = Array(samples[0...(count-1)-halfLength])
    var postSamples = Array(samples[(count-1)-halfLength+1...count-1])
    
    postSamples = amplitudeZeroSamplesDown(postSamples)
    
    var joined = startSamples
    joined.append(contentsOf: postSamples)
    
    return joined
}

func amplitudeZeroSamples_frontEndUp_backEndDown(_ samples:[Int16], scalingPercent:Int) -> [Int16] {
    let frontEnd = amplitudeZeroSamples_frontEndUp(samples, scalingPercent: scalingPercent)
    return amplitudeZeroSamples_backEndDown(frontEnd, scalingPercent: scalingPercent)
}

    // To soften clicks ramp the audio buffers at the front and back where frequency changes
enum BufferRampType: String, CaseIterable, Identifiable {
    case none, frontUp, backDown
    var id: Self { self }
}


extension ToneWriter {
    func audioSamplesForRange(component:Component, sampleRate:Int, sampleRange:ClosedRange<Int>, rampType: BufferRampType) -> [Int16] {
        
        var samples:[Int16] = []
        
        let delta_t:Double = 1.0 / Double(sampleRate)
        
        for i in sampleRange.lowerBound...sampleRange.upperBound {
            let t = Double(i) * delta_t
            
            var value = component.value(x: t) * Double(Int16.max)
            if let scale = scale {
                value = scale(t) * value
            }
            let valueInt16 = Int16(max(min(value, Double(Int16.max)), Double(Int16.min)))
            samples.append(valueInt16)
        }
        
        switch rampType {
            case .none:
                break
            case .frontUp:
                samples = amplitudeZeroSamples_frontEndUp(samples, scalingPercent: 50)
            case .backDown:
                samples = amplitudeZeroSamples_backEndDown(samples, scalingPercent: 50)
        }
        
        return samples
    }
    
    func sampleBufferForComponent(component:Component, sampleRate:Int, bufferSize: Int, rampType: BufferRampType, bufferIndex:Int, samplesRemaining:Int?) -> CMSampleBuffer? {
        
        let audioSamples = audioSamplesForRange(component: component, sampleRate: sampleRate, sampleRange: rangeForIndex(bufferIndex:bufferIndex, bufferSize: bufferSize, samplesRemaining: samplesRemaining), rampType: rampType)
        
        return sampleBufferForSamples(audioSamples: audioSamples, bufferIndex: bufferIndex, sampleRate: sampleRate, bufferSize: bufferSize)
    }
    
        // TO DO
        // samplesRemaining, and consider when componentDuration is < duration of bufferSize for the sampleRate
    /*
     Alternative to saveComponentSamplesToFile for multiple components. componentDuration is the desired duration of each indivdiual component. The actual duration will differ from Double(components.count) * componentDuration by at most the duration of one sample buffer, since extra samples are not padded (as in saveComponentSamplesToFile)
     
     The componentDuration must be >= duration of bufferSize for the sampleRate, but ideally there will be more than 1 buffer per component for ramping to mitigate clicks. 
     */
    func saveComponentsSamplesToFile(components:[Component], shouldRamp:Bool, componentDuration:Double = 3, sampleRate:Int = 44100, bufferSize:Int, destinationURL:URL, completion: @escaping (URL?, String?) -> ())  {
        
        guard components.count > 1 else {
            completion(nil, "Minimum component count is 2.")
            return
        }
        
        guard componentDuration >= Double(bufferSize) / Double(sampleRate) else {
            completion(nil, "Buffer size is too large for componentDuration.")
            return
        }
        
        guard let sampleBuffer = sampleBufferForComponent(component: components[0], sampleRate: sampleRate, bufferSize:  bufferSize, rampType: BufferRampType.none, bufferIndex: 0, samplesRemaining: nil) else {
            completion(nil, "Invalid first sample buffer.")
            return
        }
        
        var actualDestinationURL = destinationURL
        
        if actualDestinationURL.pathExtension != "wav" {
            actualDestinationURL.deletePathExtension() // this can have unintended consequences, ex name = "x2.3"
            actualDestinationURL.appendPathExtension("wav")
        }
        
        try? FileManager.default.removeItem(at: actualDestinationURL)
        
        guard let assetWriter = try? AVAssetWriter(outputURL: actualDestinationURL, fileType: AVFileType.wav) else {
            completion(nil, "Can't create asset writer.")
            return
        }
        
        let sourceFormat = CMSampleBufferGetFormatDescription(sampleBuffer)
        
        let audioCompressionSettings = [AVFormatIDKey: kAudioFormatLinearPCM] as [String : Any]
        
        if assetWriter.canApply(outputSettings: audioCompressionSettings, forMediaType: AVMediaType.audio) == false {
            completion(nil, "Can't apply compression settings to asset writer.")
            return
        }
        
        let audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings:audioCompressionSettings, sourceFormatHint: sourceFormat)
        
        audioWriterInput.expectsMediaDataInRealTime = kAudioWriterExpectsMediaDataInRealTime
        
        if assetWriter.canAdd(audioWriterInput) {
            assetWriter.add(audioWriterInput)
            
        } else {
            completion(nil, "Can't add audio input to asset writer.")
            return
        }
        
        let serialQueue: DispatchQueue = DispatchQueue(label: kToneGeneratorQueue)
        
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: CMTime.zero)
        
        func finishWriting() {
            assetWriter.finishWriting {
                switch assetWriter.status {
                    case .failed:
                        
                        var errorMessage = ""
                        if let error = assetWriter.error {
                            
                            let nserr = error as NSError
                            
                            let description = nserr.localizedDescription
                            errorMessage = description
                            
                            if let failureReason = nserr.localizedFailureReason {
                                print("error = \(failureReason)")
                                errorMessage += ("Reason " + failureReason)
                            }
                        }
                        completion(nil, errorMessage)
                        print("saveComponentsSamplesToFile errorMessage = \(errorMessage)")
                        return
                    case .completed:
                        print("saveComponentsSamplesToFile completed : \(actualDestinationURL)")
                        completion(actualDestinationURL, nil)
                        return
                    default:
                        print("saveComponentsSamplesToFile other failure?")
                        completion(nil, nil)
                        return
                }
            }
        }
        
        let duration = Double(components.count) * componentDuration
        
        var nbrSampleBuffers = Int(duration * Double(sampleRate)) / bufferSize
        
        let nbrSampleBuffersPerComponent = nbrSampleBuffers / components.count
        
        nbrSampleBuffers = nbrSampleBuffersPerComponent * components.count
        
        var bufferIndex = 0
        
        audioWriterInput.requestMediaDataWhenReady(on: serialQueue) { [weak self] in
            
            while audioWriterInput.isReadyForMoreMediaData, bufferIndex < nbrSampleBuffers {
                
                var currentSampleBuffer:CMSampleBuffer?
                
                let componentsIndex = bufferIndex / nbrSampleBuffersPerComponent
                let component = components[componentsIndex]
                
                var rampType = BufferRampType.none
                
                if shouldRamp {
                    let nextComponentsIndex = (bufferIndex+1) / nbrSampleBuffersPerComponent
                    let previousComponentsIndex = (bufferIndex-1) / nbrSampleBuffersPerComponent
                    
                    if bufferIndex == 0 {
                        rampType = .frontUp
                    }
                    else if previousComponentsIndex == componentsIndex - 1 {
                        rampType = .frontUp
                    }
                    else if nextComponentsIndex == componentsIndex + 1 {
                        rampType = .backDown
                    }
                }
                
                currentSampleBuffer = self?.sampleBufferForComponent(component: component, sampleRate: sampleRate, bufferSize: bufferSize, rampType: rampType, bufferIndex: bufferIndex, samplesRemaining: nil)
                
                if let currentSampleBuffer = currentSampleBuffer {
                    audioWriterInput.append(currentSampleBuffer)
                }
                
                bufferIndex += 1
                
                if bufferIndex == nbrSampleBuffers {
                    audioWriterInput.markAsFinished()
                    finishWriting()
                }
            }
        }
    }
    
}
