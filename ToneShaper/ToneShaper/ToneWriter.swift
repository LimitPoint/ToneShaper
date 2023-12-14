//
//  ToneWriter.swift
//  TonePlayer
//
//  Created by Joseph Pagliaro on 2/21/23.
//

import SwiftUI
import Foundation
import AVFoundation

/*
 Used for audio feedback and saving audio files
 
 generateToneAudio
    playAudioFrequency - octave view, note editor
    playAudioIndex - various uses in plot view, such as edit selection operations feedback
 
 generateToneShapeAudio
    playToneShaperDocumentURL - preview tone shaper samples files in samples view
    playToneShape - preview saving to file, or from the menu view in the plot view
    exportToneShapeAudio - save to file
 
 generateToneSequenceAudio
    exportSelectedToneSequenceAudio - save audio file with sequence of notes in plot view
 
 */
class ToneWriter {
    
    let id = UUID()
       
    let kAudioWriterExpectsMediaDataInRealTime = false
    let kToneGeneratorQueue = "com.limit-point.tone-generator-queue"
    
    var scale: ((Double)->Double)? // scale factor range in [0,1]
    
    var exportLinearPCM = true {
        didSet {
            updateAudioExportProperties()
        }
    }
    var avFileType = AVFileType.wav
    var fileExtension = "wav"
    var avFormatIDKey = kAudioFormatLinearPCM
    
    deinit {
        print("ToneWriter deinit \(id)")
    }
    
    init() {
        print("ToneWriter init \(id)")
        
        updateAudioExportProperties()
    }
    
    private func updateAudioExportProperties() {
        if exportLinearPCM {
            avFileType = AVFileType.wav
            fileExtension = "wav"
            avFormatIDKey = kAudioFormatLinearPCM
        } else {
            avFileType = AVFileType.m4a
            fileExtension = "m4a"
            avFormatIDKey = kAudioFormatMPEG4AAC
        }
    }
    
    func audioSamplesForRange(component:Component, sampleRate:Int, sampleRange:ClosedRange<Int>) -> [Int16] {
        
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
        
        return samples
    }
    
    func rangeForIndex(bufferIndex:Int, bufferSize:Int, samplesRemaining:Int?) -> ClosedRange<Int> {
        let start = bufferIndex * bufferSize
        
        if let samplesRemaining = samplesRemaining {
            return start...(start + samplesRemaining - 1)
        }
        
        return start...(start + bufferSize - 1)
    }
    
    func audioFormatDescription(sampleRate:Int) -> CMAudioFormatDescription? {
        
        var asbd = AudioStreamBasicDescription()
        asbd.mSampleRate = Float64(sampleRate)
        asbd.mFormatID = kAudioFormatLinearPCM
        asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
        asbd.mBitsPerChannel = 16
        asbd.mChannelsPerFrame = 1
        asbd.mFramesPerPacket = 1
        asbd.mBytesPerFrame = 2
        asbd.mBytesPerPacket = 2
        
        var formatDesc: CMAudioFormatDescription?
                
        if CMAudioFormatDescriptionCreate(allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &formatDesc) == noErr {
            return formatDesc
        }
        
        return nil
    }
    
    func sampleBufferForSamples(audioSamples:[Int16], bufferIndex:Int, sampleRate:Int, bufferSize:Int) -> CMSampleBuffer? {
        
        var sampleBuffer:CMSampleBuffer?
        
        let bytesInt16 = MemoryLayout<Int16>.stride
        let dataSize = audioSamples.count * bytesInt16
        
        var samplesBlock:CMBlockBuffer? 
        
        let memoryBlock:UnsafeMutableRawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: dataSize,
            alignment: MemoryLayout<Int16>.alignment)
        
        let _ = audioSamples.withUnsafeBufferPointer { buffer in
            memoryBlock.initializeMemory(as: Int16.self, from: buffer.baseAddress!, count: buffer.count)
        }
        
        if CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, 
            memoryBlock: memoryBlock, 
            blockLength: dataSize, 
            blockAllocator: nil, 
            customBlockSource: nil, 
            offsetToData: 0, 
            dataLength: dataSize, 
            flags: 0, 
            blockBufferOut:&samplesBlock
        ) == kCMBlockBufferNoErr, let samplesBlock = samplesBlock {

            
            let sampleDuration = CMTimeMakeWithSeconds((1.0 / Float64(sampleRate)), preferredTimescale: Int32.max)
            
            if let formatDesc = audioFormatDescription(sampleRate: sampleRate) {
                
                let sampleTime = CMTimeMultiply(sampleDuration, multiplier: Int32(bufferIndex * bufferSize))
                
                let timingInfo = CMSampleTimingInfo(duration: sampleDuration, presentationTimeStamp: sampleTime, decodeTimeStamp: .invalid)
                
                if CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: samplesBlock, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: formatDesc, sampleCount: audioSamples.count, sampleTimingEntryCount: 1, sampleTimingArray: [timingInfo], sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sampleBuffer) == noErr, let sampleBuffer = sampleBuffer {
                    
                    guard sampleBuffer.isValid, sampleBuffer.numSamples == audioSamples.count else {
                        return nil
                    }
                }
            }
        }
        
        return sampleBuffer
    }
    
    func sampleBufferForComponent(component:Component, sampleRate:Int, bufferSize: Int, bufferIndex:Int, samplesRemaining:Int?) -> CMSampleBuffer? {
        
        let audioSamples = audioSamplesForRange(component: component, sampleRate: sampleRate, sampleRange: rangeForIndex(bufferIndex:bufferIndex, bufferSize: bufferSize, samplesRemaining: samplesRemaining))
        
        return sampleBufferForSamples(audioSamples: audioSamples, bufferIndex: bufferIndex, sampleRate: sampleRate, bufferSize: bufferSize)
    }
    
    func saveComponentSamplesToFile(component:Component, duration:Double = 3, sampleRate:Int = 44100, bufferSize:Int = 8192, destinationURL:URL, completion: @escaping (URL?, String?) -> ())  {
        
        var actualDestinationURL = destinationURL
        
        if actualDestinationURL.pathExtension != self.fileExtension {
            actualDestinationURL.deletePathExtension() // this can have unintended consequences, ex name = "x2.3"
            actualDestinationURL.appendPathExtension(self.fileExtension)
        }
        
        try? FileManager.default.removeItem(at: actualDestinationURL)
        
        guard let assetWriter = try? AVAssetWriter(outputURL: actualDestinationURL, fileType: self.avFileType) else {
            completion(nil, "Can't create asset writer.")
            return
        }
        
        guard let sourceFormat = audioFormatDescription(sampleRate: sampleRate) else {
            completion(nil, "Can't create audio format description.")
            return
        }
        
        let audioCompressionSettings = [AVFormatIDKey: self.avFormatIDKey] as [String : Any]
        
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
        
        var nbrSampleBuffers = Int(duration * Double(sampleRate)) / bufferSize
        
        let samplesRemaining = Int(duration * Double(sampleRate)) % bufferSize
        
        if samplesRemaining > 0 {
            nbrSampleBuffers += 1
        }
        
        print("samplesRemaining = \(samplesRemaining)")
        
        var bufferIndex = 0
        
        audioWriterInput.requestMediaDataWhenReady(on: serialQueue) { [weak self] in
            
            while audioWriterInput.isReadyForMoreMediaData, bufferIndex < nbrSampleBuffers {
                
                var currentSampleBuffer:CMSampleBuffer?
                
                if samplesRemaining > 0 {
                    if bufferIndex < nbrSampleBuffers-1 {
                        currentSampleBuffer = self?.sampleBufferForComponent(component: component, sampleRate: sampleRate, bufferSize: bufferSize, bufferIndex: bufferIndex, samplesRemaining: nil)
                    }
                    else {
                        currentSampleBuffer = self?.sampleBufferForComponent(component: component, sampleRate: sampleRate, bufferSize: bufferSize, bufferIndex: bufferIndex, samplesRemaining: samplesRemaining)
                    }
                }
                else {
                    currentSampleBuffer = self?.sampleBufferForComponent(component: component, sampleRate: sampleRate, bufferSize: bufferSize, bufferIndex: bufferIndex, samplesRemaining: nil)
                }
                
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


