//
//  AudioEngineManager.swift
//  ToneShaper
//
//  Created by Joseph Pagliaro on 9/18/23.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

protocol AudioEngineManagerDelegate: AnyObject { // AnyObject - required for AudioEngine's weak reference for delegate (only reference types can have weak reference to prevent retain cycle)
    func audioSamplesForRange(_ audioEngine:AudioEngineManager?, sampleRange:ClosedRange<Int>, sampleRate: Int) -> [Int16]
}

/*
 From TonePlayer's TonePlayerObservable
 */
class AudioEngineManager: ObservableObject {
    
    weak var delegate: AudioEngineManagerDelegate?
    
        // Audio Engine
    let engine = AVAudioEngine()
    var srcNode:AVAudioSourceNode?
    var sampleRate:Float = 0
    var currentIndex:Int = 0
    var inputFormat:AVAudioFormat!
        // for ramping samples on start/stop
    var stopEngineDispatchGroup:DispatchGroup?
    let stopQueue = DispatchQueue(label: "com.limit-point.tone-shaper-stop-queue")
    var stopRequested = false // used to ramp down audio volume for a smooth stop
    var startRequested = false // used to ramp up audio volume for a smooth start
    
    @Published var isPlaying = false
    
        // MARK: Audio Engine
    
        // handle notifications for changes to audio output device
#if os(iOS)     
    @Published var shouldStopPlaying = false
    @Published var shouldStartPlaying = false
    
    @objc func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let interruptionTypeRawValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeRawValue) else {
            return
        }
        
        switch interruptionType {
            case .began:
                DispatchQueue.main.async { [weak self] in
                    self?.shouldStopPlaying = true
                }
            case .ended:
                guard let interruptionOptionRawValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                    return
                }
                
                let interruptionOption = AVAudioSession.InterruptionOptions(rawValue: interruptionOptionRawValue)
                
                if interruptionOption.contains(.shouldResume) {
                    DispatchQueue.main.async { [weak self] in
                        self?.shouldStartPlaying = true
                    }
                }
            @unknown default:
                break
        }
    }
    
    @objc func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
            case .oldDeviceUnavailable:
                DispatchQueue.main.async { [weak self] in
                    self?.shouldStopPlaying = true
                }
            case .newDeviceAvailable:
                DispatchQueue.main.async { [weak self] in
                    self?.shouldStartPlaying = true
                }
            default:
                break
        }
    }
#else
    @Published var audioEngineConfigurationChangeCount:Int = 0
    
    @objc func handleAudioEngineConfigurationChange(_ notification: Notification) { 
        DispatchQueue.main.async { [weak self] in
            
            guard let self = self else {
                return
            }
            
            self.audioEngineConfigurationChangeCount += 1
        }
    }
#endif
    
    init(_ delegate:AudioEngineManagerDelegate) {
            // register for notifications to handle changes to audio output device
#if os(iOS)   
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioInterruption(notification:)), name: AVAudioSession.interruptionNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
#else
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioEngineConfigurationChange(_:)),
                                               name: .AVAudioEngineConfigurationChange,
                                               object: engine)
#endif
        
        connectAudioEngine()
        self.delegate = delegate
    }
    
    deinit {
        print("AudioEngineManager deinit")
        engine.stop()
        disconnectAudioEngine()
    }
    
    func connectAudioEngine() {
        
        let mainMixer = engine.mainMixerNode
        
        let output = engine.outputNode
        let outputFormat = output.inputFormat(forBus: 0)
        sampleRate = Float(outputFormat.sampleRate)
        
        print("The audio engine sample rate is \(sampleRate)")
        
        inputFormat = AVAudioFormat(commonFormat: outputFormat.commonFormat,
                                    sampleRate: outputFormat.sampleRate,
                                    channels: 1,
                                    interleaved: outputFormat.isInterleaved)
        
        
        
        srcNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            
            guard let self = self else {
                return OSStatus(-1)
            }
            
            let sampleRange = currentIndex...currentIndex+Int(frameCount-1)
            
            var audioSamples = self.audioSamplesForRange(sampleRange: sampleRange)
            
            if audioSamples.count != sampleRange.count {
                audioSamples = audioSamples.scaleToD(length: sampleRange.count, smoothly: true)
            }
            
            currentIndex += Int(frameCount)
            
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                
                let value = Float(audioSamples[frame]) / Float(Int16.max)
                
                for buffer in ablPointer {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    buf[frame] = value
                }
            }
            
            if self.stopRequested {
                self.stopEngineDispatchGroup?.leave()
            }
            
            return noErr
        }
        
        if let srcNode = srcNode {
            engine.attach(srcNode)
            engine.connect(srcNode, to: mainMixer, format: inputFormat)
            engine.connect(mainMixer, to: output, format: outputFormat)
            mainMixer.outputVolume = 1
        }
    }
    
    func disconnectAudioEngine() {
        if let srcNode = srcNode {
            engine.detach(srcNode)
            self.srcNode = nil
        }
    }
    
    func audioSamplesForRange(sampleRange:ClosedRange<Int>) -> [Int16] {
        
        guard let delegate = self.delegate else {
            return [Int16](repeating: 0, count: sampleRange.count)
        }
        
        if stopRequested {
            
            var samples = delegate.audioSamplesForRange(self, sampleRange: sampleRange, sampleRate: Int(sampleRate))
            
            samples = amplitudeZeroSamplesDown(samples)
            
            return samples
        }
        
        var samples = delegate.audioSamplesForRange(self, sampleRange: sampleRange, sampleRate: Int(sampleRate))
        
        if startRequested {
            samples = amplitudeZeroSamplesUp(samples)
            startRequested = false
        }
        
        return samples
    }
    
    func startPlaying(completion: @escaping (Bool) -> ()) {
        do {
            try engine.start()
            startRequested = true
            DispatchQueue.main.async { [weak self] in
                self?.isPlaying = true
                completion(true)
            }
        }
        catch {
            DispatchQueue.main.async { [weak self] in
                self?.isPlaying = false
                completion(false)
            }
            print("Error starting audio engine: \(error)")
        }
    }
    
    func stopPlaying(completion: @escaping () -> ()) {
        
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            completion()
        }
        
        if stopRequested == false, engine.isRunning {
            
            stopRequested = true
            
            stopEngineDispatchGroup = DispatchGroup()
            stopEngineDispatchGroup?.enter()
            stopEngineDispatchGroup?.notify(queue: stopQueue) { [weak self] in
                self?.stopRequested = false
                self?.engine.stop()
            }
        }
    }
}
