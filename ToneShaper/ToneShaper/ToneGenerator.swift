//
//  ToneGenerator.swift
//  TonePlayer
//
//  Created by Joseph Pagliaro on 2/3/23.
//

import Foundation

class ToneGenerator {
    
    var lastComponent:Component
    
    var phaseOffset:Double = 0
    
    var last_f1:Double
    var last_t1:Double

    init(component:Component) {
        lastComponent = component
        
        last_f1 = component.frequency
        last_t1 = 0
    }
    
    deinit {
        print("ToneGenerator deinit")
    }
    
    func ramp(_ t:Double, t1:Double, t2:Double, f1:Double, f2:Double) -> Double {
        let df = f2 - f1
        let dt = t2 - t1
        
        if dt == 0 {
            return f1
        }
        
        return f1  + (df / dt) * (t / 2 - t1)
    }
    
    func generateRampedSamples(from startComponent:Component, to endComponent:Component, sampleRate:Int, sampleRange:ClosedRange<Int>, applyPhaseOffset:Bool, applyAmplitudeInterpolation:Bool) -> [Int16] {
        
        var samples:[Int16] = []
        
        let delta_t:Double = 1.0 / Double(sampleRate)
        
        let t1 = Double(sampleRange.lowerBound) * delta_t
        let t2 = Double(sampleRange.upperBound+1) * delta_t
        
        let f1 = startComponent.frequency
        let f2 = endComponent.frequency
        
        let deltaOffset = (ramp(t1, t1: last_t1, t2: t1, f1: last_f1, f2: f1) - ramp(t1, t1: t1, t2: t2, f1: f1, f2: f2)) * t1 
        phaseOffset += deltaOffset
        
        var rampComponent = startComponent
        if applyPhaseOffset {
            rampComponent.offset = phaseOffset
        }
        
        for i in sampleRange.lowerBound...sampleRange.upperBound {
            let t = Double(i) * delta_t
            rampComponent.frequency = ramp(t, t1: t1, t2: t2, f1: f1, f2: f2)
            let p = Double(i - sampleRange.lowerBound) / Double(sampleRange.upperBound - sampleRange.lowerBound)
            if applyAmplitudeInterpolation {
                rampComponent.amplitude = startComponent.amplitude * (1-p) + endComponent.amplitude * p
            }
            
            let value = rampComponent.value(x: t) * Double(Int16.max)
            let valueInt16 = Int16(max(min(value, Double(Int16.max)), Double(Int16.min)))
            samples.append(valueInt16)
        }
        
        last_f1 = f1
        last_t1 = t1
        
        return samples
    }
    
    func audioSamplesForRange(component:Component, sampleRange:ClosedRange<Int>, sampleRate:Int, applyPhaseOffset:Bool, applyAmplitudeInterpolation:Bool) -> [Int16] {
        
        let audioSamples = generateRampedSamples(from: lastComponent, to: component, sampleRate: sampleRate, sampleRange: sampleRange, applyPhaseOffset:applyPhaseOffset, applyAmplitudeInterpolation:applyAmplitudeInterpolation)
        
        lastComponent = component
        
        return audioSamples
    }
}
