//
//  PiecewiseIntegratorToneWriter.swift
//  GraphicalArrayEditor
//
//  Created by Joseph Pagliaro on 9/9/23.
//

import SwiftUI
import AVFoundation

/*
 toneWriter.scale is applied over the duration of the tone shape
 
 Here are scale functions for experimentation.
 
 Something to note about clicks:
 
 1 - if the curve duration does not fit the total duration, last buffer can cause a click
 2 - if the scale function does not bring the volum down to zero at the ends, there can be a click between curves (see samples in GeneratePiecewiseIntegratorSample samples)
 
 */

func linear_scale(_ T:Double, _ curveDuration:Double) -> Double {
    
    let t = T.truncatingRemainder(dividingBy: curveDuration) // maps all t into range [0,curveDuration]
    
    return (curveDuration - t) / curveDuration // scale [0,curveDuration] to [0,1] linearly
}

func sine_scale(_ T:Double, _ curveDuration:Double) -> Double {
    
    let t = T.truncatingRemainder(dividingBy: curveDuration) // maps all t into range [0,curveDuration]
    
    return abs(sine(0.5 * t / curveDuration))
}

func triangle_scale(_ T:Double, _ curveDuration:Double) -> Double {
    
    let t = T.truncatingRemainder(dividingBy: curveDuration) // maps all t into range [0,curveDuration]
    
    return ( t > curveDuration / 2 ? 2 * (1 - (t / curveDuration)): 2 * (t / curveDuration))
}

func no_scale(_ T:Double, _ curveDuration:Double) -> Double {
    return 1 // no scaling - has clicking
}

func double_smoothstep_scale(_ T:Double, _ curveDuration:Double) -> Double {
    
    let t = T.truncatingRemainder(dividingBy: curveDuration) // maps all t into range [0,curveDuration]
    
    return double_smoothstep(t / curveDuration, from: 0, to: 1, range:0...0.2)
}

func wide_double_smoothstep_scale(_ T:Double, _ curveDuration:Double) -> Double {
    
    let t = T.truncatingRemainder(dividingBy: curveDuration) // maps all t into range [0,curveDuration]
    
    return double_smoothstep(t / curveDuration, from: 0, to: 1, range:0...0.5)
}

func exponential_scale(_ T:Double, _ curveDuration:Double) -> Double {
    
    let t = T.truncatingRemainder(dividingBy: curveDuration) // maps all t into range [0,curveDuration]
    
    let a = log(Double(Int16.max)) / curveDuration
    return exp(-a * t)
}

func parabolic_scale(_ T:Double, _ curveDuration:Double) -> Double {
    
    let t = T.truncatingRemainder(dividingBy: curveDuration) // maps all t into range [0,curveDuration]
    
    return pow(((t - curveDuration) / curveDuration), 2)
}

func toneShaperScale(toneShaperScaleType:ToneShaperScaleType, duration:Double) -> ((Double)->Double) {
    
    var scale:((Double)->Double)
    
    switch toneShaperScaleType {
            
        case .none:
            scale = {t in no_scale(t, duration)}
        case .linear:
            scale = {t in linear_scale(t, duration)}
        case .triangle:
            scale = {t in triangle_scale(t, duration)}
        case .sine:
            scale = {t in sine_scale(t, duration)}
        case .parabolic:
            scale = {t in parabolic_scale(t, duration)}
        case .exponential:
            scale = {t in exponential_scale(t, duration)}
        case .twoStep:
            scale = {t in double_smoothstep_scale(t, duration)}
        case .wideTwoStep:
            scale = {t in wide_double_smoothstep_scale(t, duration)}
    }
    
    return scale
}

/*
 ToneWriter subclass for writing ToneShaper files using the PiecewiseIntegrator
 */
class PiecewiseIntegratorToneWriter: ToneWriter {
    
        // click mitigation of discontinuities for when the piecwsise integrator is reset, which is flagged when the sampleRange is reset starting from 0
    /*
     As in audioSamplesForRange in ToneShaperDocument, the idea is to delay sending sample buffers to the audio engine so that when the generated samples will experience a discontinutity, the sample buffer before the discontinutity can be ramped down, and the sample buffer after ramped up
     */
    var pi_bufferIndex:Int = 0
    var pi_currentSampleBuffer:[Int16] = []
    var pi_lastSampleBuffer:[Int16] = []
    var pi_needsRampUp = false
    
    var lastVolume = 1.0
    
    func audioSamplesForRange(piecewise_integrator:PiecewiseIntegrator, piecewise_integrator_echo_offset:PiecewiseIntegrator, echoOffsetTimeSeconds: Double, sampleRate:Int, sampleRange:ClosedRange<Int>, delaySamples:Bool, componentType: WaveFunctionType) -> [Int16] {
        
        pi_currentSampleBuffer = pi_lastSampleBuffer
        
        var samples:[Int16] = []
        
        let delta_t:Double = 1.0 / Double(sampleRate)
        
        let integral = piecewise_integrator.nextIntegral(n: sampleRange.count)
        let integral_offset = piecewise_integrator_echo_offset.nextIntegral(n: sampleRange.count)
        
        let component = Component(type: componentType, frequency: 1, amplitude: 1, offset: 0)
        
        let currentVolume = piecewise_integrator_echo_offset.volume
        
        for i in sampleRange.lowerBound...sampleRange.upperBound {
           
            let t = Double(i) * delta_t
            
            let x = integral[i-sampleRange.lowerBound]
            //var value = sin(2 * .pi * x) * Double(Int16.max)
            var value = component.value(x: x) * Double(Int16.max)
            if let scale = scale {
                value = scale(t) * value // scales over the cycle duration
            }

            let x_offset = integral_offset[i-sampleRange.lowerBound]
            //var value_offset = sin(2 * .pi * x_offset) * Double(Int16.max)
            var value_offset = component.value(x: x_offset) * Double(Int16.max)
            
            let p = Double(i - sampleRange.lowerBound) / Double(sampleRange.upperBound - sampleRange.lowerBound)
            
            let volume = lastVolume * (1-p) + currentVolume * p
            //let volume = piecewise_integrator_echo_offset.volume  // compare
            
            value_offset *= volume
            if let scale = scale {
                value_offset = scale(t + echoOffsetTimeSeconds) * value_offset
            }
            
            let valueInt16 = Int16(max(min((value_offset + value) / 2.0, Double(Int16.max)), Double(Int16.min)))
            samples.append(valueInt16)
        }
        
        lastVolume = currentVolume
        
        pi_lastSampleBuffer = samples // assuming sampleRange.count never changes (otherwise scaling is applied to fit)
        
        if pi_bufferIndex == 0 && delaySamples {
            pi_bufferIndex += 1
            return [Int16](repeating: 0, count: sampleRange.count)
        }
        
            // Also see audioSamplesForRange in ToneShaperDocument
            // ramp down buffer before transition, ramp up buffer after transition
        if pi_bufferIndex != 0 && sampleRange.lowerBound == 0 {
                // the integrator was reset
                // ramp down 
            pi_currentSampleBuffer = amplitudeZeroSamplesDown(pi_currentSampleBuffer)
            pi_needsRampUp = true
        }
        
        if pi_needsRampUp && sampleRange.lowerBound == sampleRange.count {
                // the integrator was reset
                // ramp up 
            pi_currentSampleBuffer = amplitudeZeroSamplesUp(pi_currentSampleBuffer)
            pi_needsRampUp = false
        }
        
        pi_bufferIndex += 1
        
        if delaySamples {
            return pi_currentSampleBuffer
        }
    
        return samples
    }
    
    func sampleBufferWithPiecewiseIntegrator(piecewise_integrator:PiecewiseIntegrator, piecewise_integrator_echo_offset:PiecewiseIntegrator, echoOffsetTimeSeconds: Double, sampleRate:Int, bufferSize: Int, bufferIndex:Int, nbrSampleBuffers: Int, samplesRemaining:Int?, componentType: WaveFunctionType) -> CMSampleBuffer? {
        
        var audioSamples = audioSamplesForRange(piecewise_integrator: piecewise_integrator, piecewise_integrator_echo_offset: piecewise_integrator_echo_offset, echoOffsetTimeSeconds: echoOffsetTimeSeconds, sampleRate: sampleRate, sampleRange: rangeForIndex(bufferIndex:bufferIndex, bufferSize: bufferSize, samplesRemaining: samplesRemaining), delaySamples: false, componentType: componentType)
        
        // smooth out ends to mitigate clicks at start and end
        if bufferIndex == 0 {
            audioSamples = amplitudeZeroSamples_frontEndUp(audioSamples, scalingPercent: 50)
        }
        else if bufferIndex == nbrSampleBuffers-1 {
            audioSamples = amplitudeZeroSamples_backEndDown(audioSamples, scalingPercent: 50)
        }
        
        return sampleBufferForSamples(audioSamples: audioSamples, bufferIndex: bufferIndex, sampleRate: sampleRate, bufferSize: bufferSize)
    }

    func saveUserIFCurveSamplesToFile(userIFCurve:[CGPoint], curveDuration:Double, fileDuration:Double, echoOffsetTimeSeconds:Double, echoVolume: Double, sampleRate:Int = 44100, bufferSize:Int = 8192, destinationURL:URL, componentType: WaveFunctionType, completion: @escaping (URL?, String?) -> ())  {
        
        let curveSampleCount = Int(curveDuration * Double(sampleRate))
        let stepSize = 1.0 / Double(sampleRate)
        
        let piecewise_integrator = PiecewiseIntegrator(userIFCurve: userIFCurve, sampleCount: curveSampleCount, delta: stepSize)
        let piecewise_integrator_echo_offset = PiecewiseIntegrator(userIFCurve: userIFCurve, sampleCount: curveSampleCount, delta: stepSize)
        
        piecewise_integrator_echo_offset.volume = echoVolume
        
        // offset the integrator to produce the offset samples for the echo
        let echoOffsetSamples = Int(echoOffsetTimeSeconds * Double(sampleRate))
        let _ = piecewise_integrator_echo_offset.nextIntegral(n: echoOffsetSamples)
        
        var nbrSampleBuffers = Int(fileDuration * Double(sampleRate)) / bufferSize
        
        let samplesRemaining = Int(fileDuration * Double(sampleRate)) % bufferSize
        
        if samplesRemaining > 0 {
            nbrSampleBuffers += 1
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
        
        guard let sourceFormat = audioFormatDescription(sampleRate: sampleRate) else {
            completion(nil, "Can't create audio format description.")
            return
        }
        
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
        
        var bufferIndex = 0
        
        audioWriterInput.requestMediaDataWhenReady(on: serialQueue) { [weak self] in
            
            while audioWriterInput.isReadyForMoreMediaData, bufferIndex < nbrSampleBuffers {
                
                var currentSampleBuffer:CMSampleBuffer?
                
                if samplesRemaining > 0 {
                    if bufferIndex < nbrSampleBuffers-1 {
                        currentSampleBuffer = self?.sampleBufferWithPiecewiseIntegrator(piecewise_integrator:piecewise_integrator, piecewise_integrator_echo_offset: piecewise_integrator_echo_offset, echoOffsetTimeSeconds: echoOffsetTimeSeconds, sampleRate: sampleRate, bufferSize: bufferSize, bufferIndex: bufferIndex, nbrSampleBuffers: nbrSampleBuffers, samplesRemaining: nil, componentType: componentType)
                    }
                    else {
                        currentSampleBuffer = self?.sampleBufferWithPiecewiseIntegrator(piecewise_integrator:piecewise_integrator, piecewise_integrator_echo_offset: piecewise_integrator_echo_offset, echoOffsetTimeSeconds: echoOffsetTimeSeconds, sampleRate: sampleRate, bufferSize: bufferSize, bufferIndex: bufferIndex, nbrSampleBuffers: nbrSampleBuffers, samplesRemaining: samplesRemaining, componentType: componentType)
                    }
                }
                else {
                    currentSampleBuffer = self?.sampleBufferWithPiecewiseIntegrator(piecewise_integrator:piecewise_integrator, piecewise_integrator_echo_offset: piecewise_integrator_echo_offset, echoOffsetTimeSeconds: echoOffsetTimeSeconds, sampleRate: sampleRate, bufferSize: bufferSize, bufferIndex: bufferIndex, nbrSampleBuffers: nbrSampleBuffers, samplesRemaining: nil, componentType: componentType)
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
