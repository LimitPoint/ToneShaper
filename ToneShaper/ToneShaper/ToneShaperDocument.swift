//
//  ToneShaperDocument.swift
//  ToneShaper
//
//  Created by Joseph Pagliaro on 9/15/23.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

extension UTType {
    static let toneShaperDocument = UTType(exportedAs: "com.limit-point.ToneShaper.toneshaper")
}

class ToneShaperDocument: ReferenceFileDocument, GraphicalArrayDelegate, AudioEngineManagerDelegate, Equatable {
    
    var id = UUID()
    
    var fileURL: URL?
    
    var toneGenerator = ToneGenerator(component: defaultComponent)
    @Published var component:Component = defaultComponent // used for audio feedback for dragging
    
    var audioEngineManager:AudioEngineManager! // needs objectWillChange
    
    var graphicalArrayModel = GraphicalArrayModel(data: kDefaultModelData)
    var piecewise_integrator: PiecewiseIntegrator?
    var piecewise_integrator_echo_offset: PiecewiseIntegrator?
    let piToneWriter = PiecewiseIntegratorToneWriter()
    
    static var readableContentTypes: [UTType] { [.toneShaperDocument] }
    
    @Published var decodingErrorOccurred = false
    
        // GraphicalArrayDelegate
    var savedComponentFrequencyForDragging: Double = 0
    var audioEngineManagerWasPlaying: Bool = false
    
    var cancelBag = Set<AnyCancellable>()
    
    let resetPiecewiseIntegratorSerialQueue = DispatchQueue(label: "com.limit-point.resetPiecewiseIntegratorSerialQueue")
    
    @Published var resetCount:Int = 0
    
    static func == (lhs: ToneShaperDocument, rhs: ToneShaperDocument) -> Bool {
        return lhs.id == rhs.id
    }
        
    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        do {
            let graphicalArrayModelData = try JSONDecoder().decode(GraphicalArrayModelData.self, from: data)
            self.graphicalArrayModel = GraphicalArrayModel(data: graphicalArrayModelData)
        }
        catch let DecodingError.dataCorrupted(context) {
            print(context)
            decodingErrorOccurred = true
        } catch let DecodingError.keyNotFound(key, context) {
            print("Key '\(key)' not found:", context.debugDescription)
            print("codingPath:", context.codingPath)
            decodingErrorOccurred = true
        } catch let DecodingError.valueNotFound(value, context) {
            print("Value '\(value)' not found:", context.debugDescription)
            print("codingPath:", context.codingPath)
            decodingErrorOccurred = true
        } catch let DecodingError.typeMismatch(type, context)  {
            print("Type '\(type)' mismatch:", context.debugDescription)
            print("codingPath:", context.codingPath)
            decodingErrorOccurred = true
        } catch {
            print("error: ", error)
            decodingErrorOccurred = true
        }
        
        finishInit()
    }
    
    func snapshot(contentType: UTType) throws -> GraphicalArrayModelData {
        return GraphicalArrayModelData(points: self.graphicalArrayModel.points, duration: self.graphicalArrayModel.duration, minFrequency: self.graphicalArrayModel.minFrequency, maxFrequency: self.graphicalArrayModel.maxFrequency, echoOffsetTimeSeconds: self.graphicalArrayModel.echoOffsetTimeSeconds, echoVolume: self.graphicalArrayModel.echoVolume, scaleType: self.graphicalArrayModel.scaleType.rawValue, componentType: self.graphicalArrayModel.componentType.rawValue, fidelity: self.graphicalArrayModel.fidelity)
    }
    
    func fileWrapper(snapshot: GraphicalArrayModelData, configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(snapshot)
        let fileWrapper = FileWrapper(regularFileWithContents: data)
        return fileWrapper
    }
    
        // MARK: Deinit
    deinit {
        print("ToneShaperDocument deinit \(self.id)")
    }
    
    init() {
        finishInit()
    }
    
    func resetPiecewiseIntegrator() {
        
        resetCount += 1
                
        /*
         By using a serial queue and sync, it is ensured that resetPiecewiseIntegrator() statements within the block will execute sequentially and atomically.
         */
        resetPiecewiseIntegratorSerialQueue.sync { [weak self] in
            
            guard let self = self else {
                return
            }
            
            let userIFCurve = GraphicalArrayModel.userIFCurve(graphicalArrayModel.fidelity, points: graphicalArrayModel.points)
            let curveSampleCount = Int(graphicalArrayModel.duration * Double(audioEngineManager.sampleRate))
            let stepSize = 1.0 / Double(audioEngineManager.sampleRate)
            let scaleDuration = graphicalArrayModel.duration // buffer scaling (scale(t)) to mitigate clicks
            let scaleType = graphicalArrayModel.scaleType
            
            // Bug fix - setup the piecewise_integrator's locally, then assign them to properties to prevent issues with nextIntegral elsewhere
            let piecewise_integrator = PiecewiseIntegrator(userIFCurve: userIFCurve, sampleCount: curveSampleCount, delta: stepSize)
            let piecewise_integrator_echo_offset = PiecewiseIntegrator(userIFCurve: userIFCurve, sampleCount: curveSampleCount, delta: stepSize)
            
            piecewise_integrator_echo_offset.volume = graphicalArrayModel.echoVolume
            
                // offset the integrator to produce the offset samples for the echo
            let echoOffsetSamples = Int(graphicalArrayModel.echoOffsetTimeSeconds * Double(audioEngineManager.sampleRate))
            let _ = piecewise_integrator_echo_offset.nextIntegral(n: echoOffsetSamples)
            
            piToneWriter.scale = toneShaperScale(toneShaperScaleType: scaleType, duration: scaleDuration) // using graphicalArrayModel.duration here would cause a retain cycle
            self.piecewise_integrator = piecewise_integrator
            self.piecewise_integrator_echo_offset = piecewise_integrator_echo_offset
            
            audioEngineManager.currentIndex = 0 // essential to reset the counter to keep time synced with the buffer scaling (scale(t)) to mitigate clicks
        }
        
    }
    
    func finishInit() {
        graphicalArrayModel.graphicalArrayDelegate = self
        
        audioEngineManager = AudioEngineManager(self)
        
        audioEngineManager.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send() // ensures the play button us updated with correct icon for changes to isPlaying
        }.store(in: &cancelBag)
        
        graphicalArrayModel.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send() // ensures that changes to the model are received by the undo/redo buttons
        }.store(in: &cancelBag)
        
        resetPiecewiseIntegrator()
        
        audioEngineManager.$isPlaying.sink { [weak self] isPlaying in
            
            guard let self = self else {
                return
            }
            
            if isPlaying == true {
                resetPiecewiseIntegrator()
            }
            
        }.store(in: &cancelBag)
        
        graphicalArrayModel.$echoVolume.sink { [weak self] echoVolume in
            
            guard let self = self else {
                return
            }
            
            piecewise_integrator_echo_offset?.volume = echoVolume
        }.store(in: &cancelBag)
    }
    
        // MARK: AudioEngineManagerDelegate
    
    /*
     
     audioSamplesForRange provides AVAudioEngine with the samples it needs to continue playing to provide audio feedback during editing 
     
     Click mitigation of discontinuities during switching audio from dragging to regular play is similar to audioSamplesForRange in PiecewiseIntegratorToneWriter, the idea is to delay sending sample buffers to the audio engine so that when the generated samples will experience a discontinutity, the sample buffer before the discontinutity can be ramped down, and the sample buffer after ramped up.
     
     The body of this function also shares the same serial queue as resetPiecewiseIntegrator() to mitigate audio clicks between cycles on changes.
     */
    var pi_bufferIndex:Int = 0
    var pi_currentSampleBuffer:[Int16] = []
    var pi_lastSampleBuffer:[Int16] = []
    var pi_needsRampUp = false
    var rampedBufferIndex = 0
    var lastComponentFrequencyForDragging:Double = 0
    
    func audioSamplesForRange(_ audioEngine:AudioEngineManager?, sampleRange:ClosedRange<Int>, sampleRate: Int) -> [Int16] {
        
        resetPiecewiseIntegratorSerialQueue.sync { [weak self] in
            
            guard let self = self else {
                return []
            }
            
            var needsRamping = false
            if savedComponentFrequencyForDragging != lastComponentFrequencyForDragging {
                needsRamping = true
            }
            lastComponentFrequencyForDragging = savedComponentFrequencyForDragging
            
            pi_currentSampleBuffer = pi_lastSampleBuffer
            
            var samples:[Int16] 
            
            if savedComponentFrequencyForDragging == 0 { // regular play
                if let piecewise_integrator = self.piecewise_integrator, let piecewise_integrator_echo_offset = self.piecewise_integrator_echo_offset  {
                    
                    samples = piToneWriter.audioSamplesForRange(piecewise_integrator: piecewise_integrator, piecewise_integrator_echo_offset: piecewise_integrator_echo_offset, echoOffsetTimeSeconds: graphicalArrayModel.echoOffsetTimeSeconds, sampleRate: sampleRate, sampleRange: sampleRange, delaySamples: true, componentType: graphicalArrayModel.componentType)
                }
                else {
                    samples = [Int16](repeating: 0, count: sampleRange.count)
                }
            }
            else { // dragging
                samples = toneGenerator.audioSamplesForRange(component: component, sampleRange: sampleRange, sampleRate: sampleRate, applyPhaseOffset:true, applyAmplitudeInterpolation:true)
            }
            
            pi_lastSampleBuffer = samples // assuming sampleRange.count never changes (otherwise scaling is applied to fit)
            
            if pi_bufferIndex == 0 {
                pi_bufferIndex += 1
                return [Int16](repeating: 0, count: sampleRange.count)
            }
            
                // Also see audioSamplesForRange in PiecewiseIntegratorToneWriter
                // ramp down buffer before transition, ramp up buffer after transition
            if pi_bufferIndex != 0 && needsRamping {
                    // the drag/play state was changed
                    // ramp down 
                pi_currentSampleBuffer = amplitudeZeroSamplesDown(pi_currentSampleBuffer)
                pi_needsRampUp = true
                needsRamping = false
                rampedBufferIndex = pi_bufferIndex
            }
            
            if pi_needsRampUp && rampedBufferIndex == pi_bufferIndex-1 {
                    // the drag/play state was changed
                    // ramp up 
                pi_currentSampleBuffer = amplitudeZeroSamplesUp(pi_currentSampleBuffer)
                pi_needsRampUp = false
            }
            
            pi_bufferIndex += 1
            
            return pi_currentSampleBuffer
        }
    }
    
        // MARK: GraphicalArrayDelegate
    
        // point drag
    func graphicalArrayIsDragging(frequency: Double) {
        component.frequency = frequency // used by audioSamplesForRange
    }
    
    func graphicalArrayDraggingEnded() {
        component.frequency = savedComponentFrequencyForDragging
        resetPiecewiseIntegrator()
        if audioEngineManagerWasPlaying == false {
            audioEngineManager.stopPlaying {
                
            }
        }
        savedComponentFrequencyForDragging = 0
    }
    
    func graphicalArrayDraggingStarted() {
        
        savedComponentFrequencyForDragging = component.frequency //  used by audioSamplesForRange
        
        if audioEngineManager.isPlaying == false {
            audioEngineManager.startPlaying { _ in
                self.audioEngineManagerWasPlaying = false
            }
        }
        else {
            audioEngineManagerWasPlaying = true
        }
       
    }

        // coordinate axes
    func graphicalArrayDurationChanged() {
        
        graphicalArrayModel.loopCount = 1 // reset because maxLoopCount depends on duration
        
            // see the EchoSliderView
        let reproportionedEchoOffset = graphicalArrayModel.duration * graphicalArrayModel.echoOffsetProportion
        graphicalArrayModel.echoOffsetTimeSeconds = min(reproportionedEchoOffset, graphicalArrayModel.duration) // can't exceed duration
        
        resetPiecewiseIntegrator()
    }
    
    func graphicalArrayFrequencyRangeChanged() {
        resetPiecewiseIntegrator()
    }
    
        // points added or deleted
    func graphicalArrayPointAdded() {
        resetPiecewiseIntegrator()
    }
    
    func graphicalArrayPointsDeleted() {
        resetPiecewiseIntegrator()
    }
    
    func graphicalArrayPointChanged() {
        resetPiecewiseIntegrator()
    }
    
        // points loaded or drawn
    func graphicalArrayDataLoaded() {
        resetPiecewiseIntegrator()
    }
    
    func graphicalArrayAppliedDrawPoints() {
        resetPiecewiseIntegrator()
    }
    
        // selection editor
    func graphicalArraySelectionFrequencyChanged() {
        resetPiecewiseIntegrator()
    }
    
    func graphicalArraySelectionTimeChanged() {
        resetPiecewiseIntegrator()
    }
    
        // options
    func graphicalArrayEchoOffsetChanged() {
        
        graphicalArrayModel.echoOffsetProportion = graphicalArrayModel.echoOffsetTimeSeconds / graphicalArrayModel.duration
        
        resetPiecewiseIntegrator()
    }
    
    func graphicalArrayEchoVolumeChanged() {
        // no need to reset
    }
    
    func graphicalArrayScaleTypeChanged() {
        resetPiecewiseIntegrator()
    }
    
    func graphicalArrayComponentTypeChanged() {
        resetPiecewiseIntegrator()
    }
    
    func graphicalArrayFidelityChanged() {
        resetPiecewiseIntegrator()
    }
    
    func graphicalArrayAudioExportFilename() -> String? {
        return fileURL?.deletingPathExtension().lastPathComponent
    }
}
