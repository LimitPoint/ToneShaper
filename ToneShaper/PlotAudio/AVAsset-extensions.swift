//
//  AVAsset-extensions.swift
//  PlotAudio
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/plot-audio/
//
//  Created by Joseph Pagliaro on 10/1/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import AVFoundation

extension AVAsset {
    
    // 'duration' was deprecated in macOS 13.0: Use load(.duration) instead
    /*
    var durationText:String {
        let totalSeconds = CMTimeGetSeconds(self.duration)
        return AVAsset.secondsToString(secondsIn: totalSeconds)
    }
     */
    
    var durationText: String {
        get async {
            return await getDurationText()
        }
    }
    
    func getDurationText() async -> String {
        do {
            let duration = try await load(.duration)
            let totalSeconds = CMTimeGetSeconds(duration)
            return AVAsset.secondsToString(secondsIn: totalSeconds)
        } catch {
            print("\(error)")
            return "Error"
        }
    }
    
    class func secondsToString(secondsIn:Double, includeTicks:Bool = true) -> String {
        
        if secondsIn.isFinite == false || secondsIn.isNaN {
            return "∞" // sometimes secondsIn is NaN because indicatorPercent is NaN
        }
        
        let hours:Int = Int(secondsIn / 3600)
        
        let minutes:Int = Int(secondsIn.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds:Int = Int(secondsIn.truncatingRemainder(dividingBy: 60))
        let ticks:Int = Int(100 * secondsIn.truncatingRemainder(dividingBy: 1))
        
        if includeTicks {
            if hours > 0 {
                return String(format: "%i:%02i:%02i:%02i", hours, minutes, seconds, ticks)
            } else {
                return String(format: "%02i:%02i:%02i", minutes, seconds, ticks)
            }
        }
        else {
            if hours > 0 {
                return String(format: "%i:%02i:%02i", hours, minutes, seconds)
            } else {
                return String(format: "%02i:%02i", minutes, seconds)
            }
        }
    }
    
    func audioSampleBuffer(audioTrack:AVAssetTrack, outputSettings: [String : Any]?) -> CMSampleBuffer? {
        
        var buffer:CMSampleBuffer?
        
        if let audioReader = try? AVAssetReader(asset: self)  {
            
            let audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
            
            if audioReader.canAdd(audioReaderOutput) {
                audioReader.add(audioReaderOutput)
                
                if audioReader.startReading() {
                    buffer = audioReaderOutput.copyNextSampleBuffer()
                    
                    audioReader.cancelReading()
                }
            }
        }
        
        return buffer
    }
    
        // Note: the number of samples per buffer may be variable, resulting in different bufferCounts
    func audioBufferAndSampleCounts(audioTrack:AVAssetTrack, _ outputSettings:[String : Any]) -> (bufferCount:Int, sampleCount:Int) {
        
        var sampleCount:Int = 0
        var bufferCount:Int = 0
        
        if let audioReader = try? AVAssetReader(asset: self)  {
            
            let audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
            audioReader.add(audioReaderOutput)
            
            if audioReader.startReading() {
                
                while audioReader.status == .reading {
                    if let sampleBuffer = audioReaderOutput.copyNextSampleBuffer() {
                        sampleCount += sampleBuffer.numSamples
                        bufferCount += 1
                    }
                    else {
                        audioReader.cancelReading()
                    }
                }
            }
        }
        
        return (bufferCount, sampleCount)
    }
}

