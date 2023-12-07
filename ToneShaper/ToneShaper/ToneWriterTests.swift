//
//  ToneWriterTests.swift
//  ToneShaper
//
//  Created by Joseph Pagliaro on 10/27/23.
//

import SwiftUI
import Foundation
import AVFoundation

/*
 Examples:
 
    GenerateTonePlayerSample()
 
    TestToneWriterExtensions(wavetype: WaveFunctionType.sine, frequencies: [123, 500, 900, 400, 100], amplitude: 1, duration: 0.1, bufferSize: 1024, shouldRamp: true)
 
    GeneratePiecewiseIntegratorSample(echoOffsetTimeSeconds: 0.0)
    GeneratePiecewiseIntegratorSample(echoOffsetTimeSeconds: 0.05)
    GeneratePiecewiseIntegratorSample(echoOffsetTimeSeconds: 0.1)
 */

// MARK: TestToneWriter
var testToneWriter = ToneWriter()

/*
 Solve for t: e^(-2t) = 1/Int16.max, smallest positive value of Int16 (where positive means > 0)
 
 or in WolframAlpha:
 
 'evaluate solve exp(-2t) = Divide[1,32767.0] -> t = 5.1985885951776919399153766837350066151723800263211215177494011314'
 */
func GenerateTonePlayerSample() {
    let D = -log(1.0/Double(Int16.max)) / 2.0 // D = 5.198588595177692
    print(D)
    let scale:((Double)->Double) = {t in exp(-2 * t)} 
    TestToneWriter(wavetype: .sine, frequency: 440, amplitude: 1, duration: D, scale: scale)
}

func TestToneWriter(wavetype: WaveFunctionType, frequency:Double, amplitude: Double, duration: Double, scale: ((Double)->Double)? = nil) {
    if let documentsURL = FileManager.documentsURL(filename: nil, subdirectoryName: nil) {
        print(documentsURL)
        
        let destinationURL = documentsURL.appendingPathComponent("tonewriter - \(wavetype), \(frequency) hz, \(duration).wav")
        
        testToneWriter.scale = scale
        
        testToneWriter.saveComponentSamplesToFile(component: Component(type: wavetype, frequency: frequency, amplitude: amplitude, offset: 0), duration: duration,  destinationURL: destinationURL) { resultURL, message in
            if let resultURL = resultURL {
#if os(macOS)
                NSWorkspace.shared.open(resultURL)
#endif
                let asset = AVAsset(url: resultURL)
                Task {
                    do {
                        let duration = try await asset.load(.duration)
                        print("ToneWriter : audio duration = \(duration.seconds)")
                    }
                    catch {
                        print("\(error)")
                    }
                }
            }
            else {
                print("An error occurred : \(message ?? "No error message available.")")
            }
        }
    }
}

// MARK: TestToneWriterExtensions

var testToneWriterExtensions = ToneWriter()

    // bufferSize should be small for small duration to ensure no clicks for shouldRamp = true, see comments at saveComponentsSamplesToFile
func TestToneWriterExtensions(wavetype: WaveFunctionType, frequencies:[Double], amplitude: Double, duration: Double, bufferSize: Int, shouldRamp:Bool, scale: ((Double)->Double)? = nil) {
    if let documentsURL = FileManager.documentsURL(filename: nil, subdirectoryName: nil) {
        print(documentsURL)
        
        let destinationURL = documentsURL.appendingPathComponent("tonewriter - \(wavetype), \(frequencies) hz, \(duration), \(shouldRamp).wav")
        
        testToneWriterExtensions.scale = scale
        
        let components = frequencies.map { frequency in
            Component(type: wavetype, frequency: frequency, amplitude: amplitude, offset: 0)
        }
        
            // buffer size must adapt to duration if it is too small
            // saveComponentsSamplesToFile requires that : componentDuration >= Double(bufferSize) / Double(sampleRate)
            // But there should be at least 2 buffers for each, to mitigate clicks; see comments at saveComponentsSamplesToFile. 
        testToneWriterExtensions.saveComponentsSamplesToFile(components: components, shouldRamp: shouldRamp, componentDuration: duration,  bufferSize: bufferSize, destinationURL: destinationURL) { resultURL, message in
            if let resultURL = resultURL {
#if os(macOS)
                NSWorkspace.shared.open(resultURL)
#endif
                let asset = AVAsset(url: resultURL)
                Task {
                    do {
                        let duration = try await asset.load(.duration)
                        print("ToneWriter : audio duration = \(duration.seconds)")
                    }
                    catch {
                        print("\(error)")
                    }
                }
            }
            else {
                print("An error occurred : \(message ?? "No error message available.")")
            }
        }
    }
}

// MARK: TestPiecewiseIntegratorToneWriter

/*
 GeneratePiecewiseIntegratorSample(echoOffsetTimeSeconds: 0.0)
 GeneratePiecewiseIntegratorSample(echoOffsetTimeSeconds: 0.05)
 GeneratePiecewiseIntegratorSample(echoOffsetTimeSeconds: 0.1)
 */
func GeneratePiecewiseIntegratorSample(echoOffsetTimeSeconds:Double, echoVolume: Double) {
    let fileDuration:Double = 5
    let curveDuration:Double = 5 // 1.0 / 6.0
    
    let N:Double = 500
    
    let DF:Double = N/6
    
    let x:[Double] = [0 * DF, 1 * DF, 2 * DF, 3 * DF, 4 * DF, 5 * DF, 6 * DF]
    let y:[Double] = [50,100,200,400,20,50,70] //[30,440,50,440,50,440,50] //[100, 880, 1600, 470, 50, 400, 880]
    
    let userIFCurve:[CGPoint] = [CGPoint(x: x[0], y: y[0]), CGPoint(x: x[1], y: y[1]), CGPoint(x: x[2], y: y[2]), CGPoint(x: x[3], y: y[3]), CGPoint(x: x[4], y: y[4]), CGPoint(x: x[5], y: y[5]), CGPoint(x: x[6], y: y[6])]
    
    let scale:((Double)->Double) = {t in sine_scale(t, curveDuration)} // {t in no_scale(t, curveDuration)} // {t in linear_scale(t, curveDuration)}  //{t in sine_scale(t, curveDuration)} 
    
    TestPiecewiseIntegratorToneWriter(userIFCurve: userIFCurve, curveDuration: curveDuration, wavetype: .sine, frequency: 1, amplitude: 1, fileDuration: fileDuration, echoOffsetTimeSeconds: echoOffsetTimeSeconds, echoVolume: echoVolume, scale: scale)
}

var piecewiseIntegratorToneWriter = PiecewiseIntegratorToneWriter()

func TestPiecewiseIntegratorToneWriter(userIFCurve:[CGPoint], curveDuration:Double, wavetype: WaveFunctionType, frequency:Double, amplitude: Double, fileDuration: Double, echoOffsetTimeSeconds: Double, echoVolume: Double, scale: ((Double)->Double)? = nil) {
    if let documentsURL = FileManager.documentsURL(filename: nil, subdirectoryName: nil) {
        print(documentsURL)
        
        let destinationURL = documentsURL.appendingPathComponent("tonewriter ech - \(echoOffsetTimeSeconds).wav")
        
        piecewiseIntegratorToneWriter.scale = scale
        
        piecewiseIntegratorToneWriter.saveUserIFCurveSamplesToFile(userIFCurve: userIFCurve, curveDuration: curveDuration, fileDuration: fileDuration, echoOffsetTimeSeconds: echoOffsetTimeSeconds, echoVolume: echoVolume,  destinationURL: destinationURL, componentType: .sine) { resultURL, message in
            if let resultURL = resultURL {
#if os(macOS)
                NSWorkspace.shared.open(resultURL)
#endif
                let asset = AVAsset(url: resultURL)
                Task {
                    do {
                        let duration = try await asset.load(.duration)
                        print("ToneWriter : audio duration = \(duration.seconds)")
                    }
                    catch {
                        print("\(error)")
                    }
                }
            }
            else {
                print("An error occurred : \(message ?? "No error message available.")")
            }
        }
    }
}
