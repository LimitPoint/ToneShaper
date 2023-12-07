//
//  GraphicalArrayModel.swift
//  GraphicalArrayEditor
//
//  Created by Joseph Pagliaro on 9/7/23.
//

import Combine
import AVFoundation

let labelOffset = 15.0

let pointDiameter: CGFloat = 10
let pointTapMinimumDistance = 3 * pointDiameter

let kGAEAudioExportName = "ToneShaper Audio Export" 
let kGAETemporarySubdirectoryName = "GAETemporaryItems" // cleared on init!

let componentDurations = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0] // for playing point frequecy

let durationRange:ClosedRange<CGFloat> = 0.03...30.0 // tone shape duration

struct GAAlertInfo: Identifiable {
    
    enum AlertType {
        // plot view - delete and reset buttons
        case delete // no longer alerted
        case reset
        case stepped
        
        // draw view - apply and erase
        case apply
        case canNotApply
        case erase
        
        // export tone shape
        case exporterSuccess
        case exporterFailed
        
        // save tone shape image
        case imageSavedToPhotos
        case imageNotSavedToPhotos
        
        // apply sample data
        case applySample
    }
    
    let id: AlertType
    let title: String
    let message: String
    let action: () -> Void
}

enum GAEToneRampType: String, CaseIterable, Identifiable {
    case none, linear, parabolic, exponential, triangle, sine
    var id: Self { self }
}

/*
 Insert a point maintaining x-coordinate order 
 */
func insertPoint(_ point: CGPoint, into array: inout [CGPoint]) -> Int {
    if array.isEmpty {
        array.append(point)
        return 0
    }
    
    var left = 0
    var right = array.count - 1
    
    while left <= right {
        let mid = (left + right) / 2
        let midPoint = array[mid]
        
        if point.x < midPoint.x {
            right = mid - 1
        } else {
            left = mid + 1
        }
    }
    
    array.insert(point, at: left)
    
    return left
}

extension CGPoint {
    func distance(to otherPoint: CGPoint) -> CGFloat {
        let dx = self.x - otherPoint.x
        let dy = self.y - otherPoint.y
        return sqrt(dx * dx + dy * dy)
    }
}

func isPointWithinDistance(_ pointP: CGPoint, _ arrayA: [CGPoint], _ distanceD: CGFloat, _ map: (CGPoint)->(CGPoint)) -> Bool {
    for point in arrayA {
        if map(point).distance(to: pointP) <= distanceD {
            return true
        }
    }
    return false
}

/*
 Notation:
 
 A ~ defining the userIFCurve (for userIFValues) - the instantaneous frequency as a function of time.
 
 V ~ the corresponding array in the graphical view for editing.
 
 */

protocol GraphicalArrayDelegate: AnyObject { // AnyObject - required for weak reference for delegate (only reference types can have weak reference to prevent retain cycle)
    
    // export filename
    func graphicalArrayAudioExportFilename() -> String?
    
    // point drag
    func graphicalArrayIsDragging(frequency: Double)
    func graphicalArrayDraggingEnded()
    func graphicalArrayDraggingStarted()
    
    // coordinate axes
    func graphicalArrayDurationChanged()
    func graphicalArrayFrequencyRangeChanged()
    
    // points added or deleted
    func graphicalArrayPointAdded()
    func graphicalArrayPointsDeleted()
    func graphicalArrayPointChanged() 
    
    // points loaded or drawn
    func graphicalArrayDataLoaded()
    func graphicalArrayAppliedDrawPoints() 
    
    // selection editor
    func graphicalArraySelectionFrequencyChanged()
    func graphicalArraySelectionTimeChanged()
    
    // options
    func graphicalArrayEchoOffsetChanged()
    func graphicalArrayEchoVolumeChanged()
    func graphicalArrayScaleTypeChanged()
    func graphicalArrayComponentTypeChanged()
    func graphicalArrayFidelityChanged()
}

enum EqualizationType: String, CaseIterable, Identifiable {
    case average = "Average", minimum = "Minimum", maximum = "Maximum", first = "First", last = "Last", equalSpacedTime = "Equal Spaced Time", selectedNote = "Selected Note"
    var id: Self { self }
}

enum ToneShaperScaleType: String, CaseIterable, Identifiable {
    case none = "None", linear = "Linear", sine = "Sine", triangle = "Triangle", parabolic = "Parabolic", exponential = "Exponential", twoStep = "Two Step", wideTwoStep = "Wide Two Step"
    var id: Self { self }
} 

func SetProperties(from data: GraphicalArrayModelData, echoOffsetTimeSeconds: inout Double, echoVolume: inout Double, scaleType: inout ToneShaperScaleType, componentType: inout WaveFunctionType, fidelity: inout Int) {
    
    echoOffsetTimeSeconds = 0
    echoVolume = 1
    scaleType = kDefaultScaleType
    componentType = kDefaultComponentType
    fidelity = kUserIFCurvePointCount
    
    if let value = data.echoOffsetTimeSeconds {
        echoOffsetTimeSeconds = value
    }
    
    if let value = data.echoVolume {
        echoVolume = value
    }
    
    if let scaleTypeString = data.scaleType, let value = ToneShaperScaleType(rawValue: scaleTypeString) {
        scaleType = value
    }
    
    if let componentTypeString = data.componentType, let value = WaveFunctionType(rawValue: componentTypeString) {
        componentType = value
    }
    
    if let value = data.fidelity {
        fidelity = value
    }
}

class GraphicalArrayModel: NSObject, ObservableObject, AVAudioPlayerDelegate, AudioPlayerDelegate, PlotAudioDelegate {
    
    var id = UUID()
    
    let toneWriter = ToneWriter()
    let piToneWriter = PiecewiseIntegratorToneWriter()
    
    @Published var plotAudioObservable = PlotAudioObservable(frameSize: CGSize(width: 300, height: 15))
    
    @Published var points:[CGPoint]  // array A of time and instantaneous frequency
    @Published var selectedPointIndices: Set<Int> = []
    
    @Published var duration: CGFloat// array A x-coordinate upper bound
    @Published var minFrequency: CGFloat // array A, y-coordinate lower bound
    @Published var maxFrequency: CGFloat // array A, y-coordinate upper bound
    @Published var loopCount: Int = 1
    
    @Published var labelType = kDefaultLabelType
    @Published var highlightNotes = true
    
    @Published var echoOffsetTimeSeconds = 0.0
    var echoOffsetProportion:Double = 0
    @Published var echoVolume = 1.0
    @Published var fidelity:Int = kUserIFCurvePointCount
    @Published var scaleType:ToneShaperScaleType = kDefaultScaleType
    @Published var componentType:WaveFunctionType = kDefaultComponentType
    
    let octavesArray = OctavesArray()
    @Published var octaveViewColumnsCount = 3
    @Published var isShowingOctaveView = false
    @Published var selectedNoteFrequency:Double?
    var onOctaveViewNoteTap:(Double) -> Void = { _ in }
    
    weak var graphicalArrayDelegate: GraphicalArrayDelegate? // weak to prevent retain cycle
    
    var maxLoopCount: Int {
        let maxD = durationRange.upperBound 
        return Int(maxD / duration)
    }
    
        // Property to store the current size of the associated view
    @Published var viewSize: CGSize = .zero // array `V` as view coordinates locations for `A`
    
    // Audio play and export
    var audioDocument:AudioDocument?
    @Published var showAudioExporter: Bool = false
    @Published var isExporting = false
    var avAudioPlayer: AVAudioPlayer?
    @Published var componentDuration = componentDurations[0]
    var indicesToPlay: [Int]?
    @Published var speakerOn = true
    
    var audioPlayer:AudioPlayer
    @Published var indicatorPercent:Double = 0
    @Published var isPreparingToPlay = false
    
    @Published var alertInfo:GAAlertInfo?
    
    // Disclsoure Groups
    @Published var isSelectionViewExpanded:Bool = false
    @Published var isNotePickerViewExpanded:Bool = false
    @Published var isOptionsViewExpanded:Bool = false
    @Published var isFrequencyRangeViewExpanded = false
    @Published var isDurationViewExpanded = false
    @Published var isExportViewExpanded:Bool = false
    
    var cancelBag = Set<AnyCancellable>()
    
    init(data:GraphicalArrayModelData) {
        
        points = data.points
        duration = data.duration
        minFrequency = data.minFrequency
        maxFrequency = data.maxFrequency
        
        audioPlayer = AudioPlayer()
        
        super.init()
        
            // set options from data
        echoOffsetTimeSeconds = 0
        echoVolume = 1
        scaleType = kDefaultScaleType
        componentType = kDefaultComponentType
        fidelity = kUserIFCurvePointCount
        
        SetProperties(from: data, echoOffsetTimeSeconds: &echoOffsetTimeSeconds, echoVolume: &echoVolume, scaleType: &scaleType, componentType: &componentType, fidelity: &fidelity)
        
        echoOffsetProportion = echoOffsetTimeSeconds / duration
        
        FileManager.deleteDocumentsSubdirectory(subdirectoryName: kGAETemporarySubdirectoryName)
        
        audioPlayer.delegate = self
        plotAudioObservable.plotAudioDelegate = self
        
        $duration.sink { [weak self] new_duration in
            
            guard let self = self else {
                return
            }
            
            guard durationRange.contains(new_duration) else {
                return
            }
            
            points = updatePointsTimes(fromDurationRange: 0...duration, toDurationRange: 0...new_duration)
        }
        .store(in: &cancelBag)
        
        $minFrequency.sink { [weak self] new_minFrequency in
            
            guard let self = self else {
                return
            }
            
            guard minFrequency <= maxFrequency, new_minFrequency <= maxFrequency else {
                return
            }
            
            let newFrequencyRange:ClosedRange<Double> = new_minFrequency...maxFrequency
            
            points = updatePointsFrequencies(fromFrequencyRange: minFrequency...maxFrequency, toFrequencyRange: newFrequencyRange)
            
            if let frequency = selectedNoteFrequency, newFrequencyRange.contains(frequency) == false {
                selectedNoteFrequency = nil
            }
        }
        .store(in: &cancelBag)
        
        $maxFrequency.sink { [weak self] new_maxFrequency in
            
            guard let self = self else {
                return
            }
            
            guard minFrequency <= maxFrequency, new_maxFrequency >= minFrequency else {
                return
            }
            
            let newFrequencyRange:ClosedRange<Double> = minFrequency...new_maxFrequency
            
            points = updatePointsFrequencies(fromFrequencyRange: minFrequency...maxFrequency, toFrequencyRange: newFrequencyRange)
            
            if let frequency = selectedNoteFrequency, newFrequencyRange.contains(frequency) == false {
                selectedNoteFrequency = nil
            }
        }
        .store(in: &cancelBag)
        
        $isExportViewExpanded.sink { [weak self] new_isExportViewExpanded in
            if new_isExportViewExpanded == false {
                self?.indicatorPercent = 0
                self?.plotAudioObservable.indicatorPercent = 0
            }
        }
        .store(in: &cancelBag)
    }
    
    deinit {
        print("GraphicalArrayModel deinit \(self.id)")
    }
    
    func registerUndoForDurationSlider(oldValue:Double, undoManager:UndoManager?) {
        
        let currentDuration = duration
        
        undoManager?.registerUndo(withTarget: self) { model in
            model.duration = oldValue
            model.graphicalArrayDelegate?.graphicalArrayDurationChanged()
            
            undoManager?.registerUndo(withTarget: self) { model in
                model.duration = currentDuration
                model.registerUndoForDurationSlider(oldValue:oldValue, undoManager:undoManager)
                model.graphicalArrayDelegate?.graphicalArrayDurationChanged()
            }
        }
    }
    
    func registerUndoForEchoOffsetSlider(oldValue:Double, undoManager:UndoManager?) {
        
        let currentEchoOffset = echoOffsetTimeSeconds
        
        undoManager?.registerUndo(withTarget: self) { model in
            model.echoOffsetTimeSeconds = oldValue
            model.graphicalArrayDelegate?.graphicalArrayEchoOffsetChanged()
            
            undoManager?.registerUndo(withTarget: self) { model in
                model.echoOffsetTimeSeconds = currentEchoOffset
                model.registerUndoForEchoOffsetSlider(oldValue: oldValue, undoManager: undoManager) 
                model.graphicalArrayDelegate?.graphicalArrayEchoOffsetChanged()
            }
        }
    }
    
    func registerUndoForEchoVolumeSlider(oldValue:Double, undoManager:UndoManager?) {
        
        let currentEchoVolume = echoVolume
        
        undoManager?.registerUndo(withTarget: self) { model in
            model.echoVolume = oldValue
            model.graphicalArrayDelegate?.graphicalArrayEchoVolumeChanged()
            
            undoManager?.registerUndo(withTarget: self) { model in
                model.echoVolume = currentEchoVolume
                model.registerUndoForEchoVolumeSlider(oldValue: oldValue, undoManager: undoManager) 
                model.graphicalArrayDelegate?.graphicalArrayEchoVolumeChanged()
            }
        }
    }
    
    func registerUndoForFidelitySlider(oldValue:Int, undoManager:UndoManager?) {
        
        let currentFidelity = fidelity
        
        undoManager?.registerUndo(withTarget: self) { model in
            model.fidelity = oldValue
            model.graphicalArrayDelegate?.graphicalArrayFidelityChanged()
            
            undoManager?.registerUndo(withTarget: self) { model in
                model.fidelity = currentFidelity
                model.registerUndoForFidelitySlider(oldValue: oldValue, undoManager: undoManager) 
                model.graphicalArrayDelegate?.graphicalArrayFidelityChanged()
            }
        }
    }
    
    func registerUndoForComponentTypePicker(oldValue:WaveFunctionType, undoManager:UndoManager?) {
        
        let currentComponentType = componentType
        
        undoManager?.registerUndo(withTarget: self) { model in
            model.componentType = oldValue
            model.graphicalArrayDelegate?.graphicalArrayComponentTypeChanged()
            
            undoManager?.registerUndo(withTarget: self) { model in
                model.componentType = currentComponentType
                model.registerUndoForComponentTypePicker(oldValue: oldValue, undoManager: undoManager) 
                model.graphicalArrayDelegate?.graphicalArrayComponentTypeChanged()
            }
        }
    }
    
    func registerUndoForScaleTypePicker(oldValue:ToneShaperScaleType, undoManager:UndoManager?) {
        
        let currentScaleType = scaleType
        
        undoManager?.registerUndo(withTarget: self) { model in
            model.scaleType = oldValue
            model.graphicalArrayDelegate?.graphicalArrayScaleTypeChanged()
            
            undoManager?.registerUndo(withTarget: self) { model in
                model.scaleType = currentScaleType
                model.registerUndoForScaleTypePicker(oldValue: oldValue, undoManager: undoManager) 
                model.graphicalArrayDelegate?.graphicalArrayScaleTypeChanged()
            }
        }
    }
    
    func validate(points:[CGPoint], duration: Double, minFrequency: Double, maxFrequency: Double) -> Bool {
        guard points[0].x == 0, points[points.count-1].x == duration else {
            return false
        }
        
        guard points[0].y >= minFrequency && points[0].y <= maxFrequency else {
            return false
        }
        
        for i in 1...points.count-1 {
            guard points[i].y >= minFrequency && points[i].y <= maxFrequency else {
                return false
            }
            
            guard points[i-1].x < points[i].x else {
                return false
            }
        }
        
        return true
    }
    
    func registerUndoForFrequencyRangeSlider(oldRange: ClosedRange<Double>, undoManager:UndoManager?) {
        
        let currentRange:ClosedRange<Double> = minFrequency...maxFrequency
        
        undoManager?.registerUndo(withTarget: self) { model in
            model.minFrequency = oldRange.lowerBound
            model.maxFrequency = oldRange.upperBound
            model.graphicalArrayDelegate?.graphicalArrayFrequencyRangeChanged()
            
            undoManager?.registerUndo(withTarget: self) { model in
                model.minFrequency = currentRange.lowerBound
                model.maxFrequency = currentRange.upperBound
                model.registerUndoForFrequencyRangeSlider(oldRange: oldRange, undoManager: undoManager)
                model.graphicalArrayDelegate?.graphicalArrayFrequencyRangeChanged()
            }
        }
    }
    
    func registerUndoForDragging(index:Int?, oldPoint:CGPoint?, undoManager:UndoManager?) {
        
        guard let index = index, let oldPoint = oldPoint, points.isValid(index: index) else {
            return
        }
        
        let currentPoint = points[index]
        
        // do not use `self` in registerUndo - use the model in the closure
        undoManager?.registerUndo(withTarget: self) { model in
            
            guard model.points.isValid(index: index) else {
                return
            }
            
            var editedPoints = model.points
            editedPoints[index] = oldPoint
            
            if model.validate(points: editedPoints, duration: model.duration, minFrequency: model.minFrequency, maxFrequency: model.maxFrequency) {
                
                model.points[index] = oldPoint
                model.graphicalArrayDelegate?.graphicalArrayPointChanged()
                
                undoManager?.registerUndo(withTarget: self) { model in
                    
                    guard model.points.isValid(index: index) else {
                        return
                    }
                    
                    var editedPoints = model.points
                    editedPoints[index] = currentPoint
                    
                    if model.validate(points: editedPoints, duration: model.duration, minFrequency: model.minFrequency, maxFrequency: model.maxFrequency) {
                        model.points[index] = currentPoint
                        model.registerUndoForDragging(index:index, oldPoint:oldPoint, undoManager:undoManager)
                        model.graphicalArrayDelegate?.graphicalArrayPointChanged()
                    }
                }
            }
        }
    }
    
    func updatePointsTimes(fromDurationRange: ClosedRange<Double>, toDurationRange: ClosedRange<Double>) -> [CGPoint] {
        
        var updatedPoints:[CGPoint] = []
        
        for point in points {
            let mappedTime = mapRangeValue(point.x, fromRange: fromDurationRange, toRange: toDurationRange)
            updatedPoints.append(CGPoint(x: mappedTime, y: point.y))
        }
        
        return updatedPoints
    }
    
    
    func updatePointsFrequencies(fromFrequencyRange: ClosedRange<Double>, toFrequencyRange: ClosedRange<Double>) -> [CGPoint] {
        
        var updatedPoints:[CGPoint] = []
        
        for point in points {
            let mappedFrequency = mapRangeValue(point.y, fromRange: fromFrequencyRange, toRange: toFrequencyRange)
            updatedPoints.append(CGPoint(x: point.x, y: mappedFrequency))
        }
        
        return updatedPoints
    }
    
        // Map points drawPoints in draw view's coordinate space of drawViewSize to the frequency range (minFrequency, maxFrequency)
    func updatePointsFromDrawPoints(drawPoints:[CGPoint], drawViewSize:CGSize, undoManager: UndoManager?) -> Bool {
        
        let flippedPoints = flipPointsForView(points: drawPoints, viewSize: drawViewSize)
        
        let oldPoints = points
        
        points = flippedPoints.map({ point in
            LVA(point, V: [CGPoint(x: 0, y: 0), CGPoint(x: drawViewSize.width, y: drawViewSize.height)], A: [CGPoint(x: 0, y: minFrequency), CGPoint(x: duration, y: maxFrequency)])
        })
        
        let mappedPoints = flippedPoints.map({ point in
            LVA(point, V: [CGPoint(x: 0, y: 0), CGPoint(x: drawViewSize.width, y: drawViewSize.height)], A: [CGPoint(x: 0, y: minFrequency), CGPoint(x: duration, y: maxFrequency)])
        })
        
        if validate(points: mappedPoints, duration: duration, minFrequency: minFrequency, maxFrequency: maxFrequency) {
            
            points = mappedPoints
            
            undoManager?.registerUndo(withTarget: self) { model in
                if model.validate(points: oldPoints, duration: model.duration, minFrequency: model.minFrequency, maxFrequency: model.maxFrequency) {
                    
                    model.points = oldPoints
                    model.graphicalArrayDelegate?.graphicalArrayAppliedDrawPoints()
                    
                    undoManager?.registerUndo(withTarget: self) { model in
                        if model.updatePointsFromDrawPoints(drawPoints: drawPoints, drawViewSize: drawViewSize, undoManager: undoManager) {
                            model.graphicalArrayDelegate?.graphicalArrayAppliedDrawPoints()
                        }
                    }
                }
            }
            
            return true
        }
        
        return false
    }
    
    func setModelData(from newModelData: GraphicalArrayModelData) {
        duration = newModelData.duration
        minFrequency = newModelData.minFrequency
        maxFrequency = newModelData.maxFrequency
        points = newModelData.points 
        
            // set options from data
        echoOffsetTimeSeconds = 0
        echoVolume = 1
        scaleType = kDefaultScaleType
        componentType = kDefaultComponentType
        fidelity = kUserIFCurvePointCount
        
        SetProperties(from: newModelData, echoOffsetTimeSeconds: &echoOffsetTimeSeconds, echoVolume: &echoVolume, scaleType: &scaleType, componentType: &componentType, fidelity: &fidelity)
        
        echoOffsetProportion = echoOffsetTimeSeconds / duration
    }
    
    func reset(undoManager: UndoManager?) {
        
        let oldModelData = GraphicalArrayModelData(points: self.points, duration: self.duration, minFrequency: self.minFrequency, maxFrequency: self.maxFrequency, echoOffsetTimeSeconds: self.echoOffsetTimeSeconds, echoVolume: self.echoVolume, scaleType: self.scaleType.rawValue, componentType: self.componentType.rawValue, fidelity: self.fidelity)
        
        let selectedPointIndices = self.selectedPointIndices
        
        setModelData(from: kDefaultModelData)
        
        undoManager?.registerUndo(withTarget: self) { model in
            
            model.setModelData(from: oldModelData)
            model.selectedPointIndices = selectedPointIndices
            model.graphicalArrayDelegate?.graphicalArrayDataLoaded()
            
            undoManager?.registerUndo(withTarget: self) { model in
                model.reset(undoManager: undoManager)
                model.graphicalArrayDelegate?.graphicalArrayDataLoaded()
            }
        }
    }
    
    func convertPointsToSteps(undoManager: UndoManager?) -> Bool {
        
        func transformToStepped(points: [CGPoint]) -> [CGPoint] {
            guard points.count >= 2 else {
                return points // Nothing to transform if there are fewer than two points.
            }
            
            var stepFunctionPoints = [CGPoint]()
            
            for i in 0..<points.count - 1 {
                let pointA = points[i]
                let pointB = points[i + 1]
                
                stepFunctionPoints.append(pointA) // Add the original pointA
                
                let M = (pointA.x + pointB.x) / 2
                let maxT = min((pointB.x - M) / 2, (M - pointA.x) / 2)
                let smallT = min(0.001, maxT) // Ensure 0 < smallT < 0.001
                
                let leftPoint = CGPoint(x: M - smallT, y: pointA.y)
                let rightPoint = CGPoint(x: M + smallT, y: pointB.y)
                
                stepFunctionPoints.append(leftPoint) // Insert left point
                stepFunctionPoints.append(rightPoint) // Insert right point
            }
            
            stepFunctionPoints.append(points.last!) // Add the last original point
            
            return stepFunctionPoints
        }
        
        func removeRedundantPoints(points: [CGPoint]) -> [CGPoint] {
                // Check if the input array has less than 3 points (cannot remove redundant points).
            guard points.count >= 3 else {
                return points
            }
            
            var filteredPoints = [points.first!] // Initialize with the first point.
            
            for i in 1..<points.count - 1 {
                let prevPoint = points[i - 1]
                let currentPoint = points[i]
                let nextPoint = points[i + 1]
                
                    // Check if the y values of the current point and its neighbors are equal.
                if prevPoint.y != currentPoint.y || currentPoint.y != nextPoint.y {
                    filteredPoints.append(currentPoint)
                }
            }
            
            filteredPoints.append(points.last!) // Add the last point.
            
            return filteredPoints
        }
        
        let originalPoints = points
        
        var steppedPoints = transformToStepped(points: points)
        steppedPoints = removeRedundantPoints(points: steppedPoints)
        
        if validate(points: steppedPoints, duration: duration, minFrequency: minFrequency, maxFrequency: maxFrequency) {
            
            points = steppedPoints
            
            undoManager?.registerUndo(withTarget: self) { model in
                if model.validate(points: originalPoints, duration: model.duration, minFrequency: model.minFrequency, maxFrequency: model.maxFrequency) {
                    
                    model.points = originalPoints
                    model.graphicalArrayDelegate?.graphicalArrayPointAdded()
                    
                    undoManager?.registerUndo(withTarget: self) { model in
                        if model.convertPointsToSteps(undoManager: undoManager) {
                            model.graphicalArrayDelegate?.graphicalArrayPointAdded()
                        }
                    }
                }
            }
            
            return true
        }
        
        return false
    }
    
        // Used to load samples in SamplesView
    func loadModelDataFromURL(fileURL: URL, undoManager: UndoManager?) {
        
        if let newModelData = GraphicalArrayModelDataForURL(fileURL: fileURL) {
            
            let oldModelData = GraphicalArrayModelData(points: self.points, duration: self.duration, minFrequency: self.minFrequency, maxFrequency: self.maxFrequency, echoOffsetTimeSeconds: self.echoOffsetTimeSeconds, echoVolume: self.echoVolume, scaleType: self.scaleType.rawValue, componentType: self.componentType.rawValue, fidelity: self.fidelity)
            let selectedPointIndices = self.selectedPointIndices
            
            self.selectedPointIndices.removeAll()
            setModelData(from: newModelData)
            
            undoManager?.registerUndo(withTarget: self) { model in
                
                model.setModelData(from: oldModelData)
                model.selectedPointIndices = selectedPointIndices
                model.graphicalArrayDelegate?.graphicalArrayDataLoaded()
                
                undoManager?.registerUndo(withTarget: self) { model in
                    model.loadModelDataFromURL(fileURL: fileURL, undoManager: undoManager)
                    model.graphicalArrayDelegate?.graphicalArrayDataLoaded()
                }
            }
        }
        
    }
    
    func resetAvailable() -> Bool {
        return points.count == 2 && self.duration == kDefaultModelData.duration && self.minFrequency == kDefaultModelData.minFrequency && self.maxFrequency == kDefaultModelData.maxFrequency
    }
    
        // Function to update the view size
    func updateViewSize(to size: CGSize) {
        viewSize = size
    }
    
        // linear mapping L from rectangle A to rectangle V, with rectangles defined using lower-left and upper-right corner points
    func LAV(_ pointInA: CGPoint, A: [CGPoint], V: [CGPoint]) -> CGPoint {
        let xFraction = (pointInA.x - A[0].x) / (A[1].x - A[0].x)
        let yFraction = (pointInA.y - A[0].y) / (A[1].y - A[0].y)
        
        let pointInV_X = xFraction * (V[1].x - V[0].x) + V[0].x
        let pointInV_Y = yFraction * (V[1].y - V[0].y) + V[0].y
        
        let pointInV = CGPoint(x: pointInV_X, y: pointInV_Y)
        
        return pointInV
    }
    
        // linear mapping L from rectangle V to rectangle A, with rectangles defined using lower-left and upper-right corner points
    func LVA(_ pointInV: CGPoint, V: [CGPoint], A: [CGPoint]) -> CGPoint {
        let xFraction = (pointInV.x - V[0].x) / (V[1].x - V[0].x)
        let yFraction = (pointInV.y - V[0].y) / (V[1].y - V[0].y)
        
        let pointInA_X = xFraction * (A[1].x - A[0].x) + A[0].x
        let pointInA_Y = yFraction * (A[1].y - A[0].y) + A[0].y
        
        let pointInA = CGPoint(x: pointInA_X, y: pointInA_Y)
        
        return pointInA
    }
    
        // Convenience function to map a point in view's coordinate space of viewSize to the frequency range (minFrequency, maxFrequency)
    func LVA(_ pointInView: CGPoint) -> CGPoint {
        return LVA(pointInView, V: [CGPoint(x: 0, y: 0), CGPoint(x: viewSize.width, y: viewSize.height)], A: [CGPoint(x: 0, y: self.minFrequency), CGPoint(x: self.duration, y: self.maxFrequency)])
    }
    
        // Convenience function to map a point the frequency range (minFrequency, maxFrequency) to view's coordinate space of viewSize
    func LAV(_ pointInA: CGPoint) -> CGPoint {
        return LAV(pointInA, A: [CGPoint(x: 0, y: self.minFrequency), CGPoint(x: self.duration, y: self.maxFrequency)], V: [CGPoint(x: 0, y: 0), CGPoint(x: viewSize.width, y: viewSize.height)])
    }
    
        // Function to add a point
    func addPoint(at point: CGPoint, undoManager: UndoManager?) {
            // Convert point from view coordinate space to A coordinate space
        let scaledPoint = LVA(point) /* Perform LVA scaling here */
        
            // Check if the point already exists in the array
        if !points.contains(scaledPoint) {
            let insertedIndex = insertPoint(scaledPoint, into: &self.points)
            
            if speakerOn {
                playAudioIndex(insertedIndex)
            }
            
            undoManager?.registerUndo(withTarget: self) { model in
                
                guard model.points.isValid(index: insertedIndex) else {
                    return
                }
                
                model.points.remove(at: insertedIndex)
                model.graphicalArrayDelegate?.graphicalArrayPointsDeleted()
                
                undoManager?.registerUndo(withTarget: self) { model in
                    model.addPoint(at: point, undoManager: undoManager)
                    model.graphicalArrayDelegate?.graphicalArrayPointAdded()
                }
            }
        }
    }
    
        // Function to select a point
    func selectPoint(at index: Int) {
        selectedPointIndices.insert(index)
    }
    
        // Function to unselect a point
    func unselectPoint(at index: Int) {
        selectedPointIndices.remove(index)
    }
    
    func selectAll() {
        let N = points.count
        (0..<N).forEach { index in
            selectedPointIndices.insert(index)
        }
    }
    
    func unselectAll() {
        selectedPointIndices.removeAll()
    }
    
    func incrementTime(_ deltaTime: Double, selectedPointIndices: Set<Int>, undoManager: UndoManager?) -> Bool {
            // Convert the set to an array and sort it
        var set = selectedPointIndices
        
        // first and last are never incremented
        set.remove(0)
        set.remove(points.count-1)
        
        let sortedIndices = Array(set).sorted()
        
        var indices:[Int] = []
        
        for i in sortedIndices {
            
            if points.isValid(index: i), points.isValid(index: i+1) {
                let valueToCompare = (set.contains(i+1) ? min(points[i+1].x + CGFloat(deltaTime), duration) :  points[i+1].x)
                
                if points[i].x + CGFloat(deltaTime) < valueToCompare {
                    indices.append(i)
                }
            }
        }
        
        if indices.count > 0 {
            
            if speakerOn, sortedIndices.count == 1 {
                playAudioIndex(sortedIndices[0])
            }
            
            for i in indices {
                points[i].x += CGFloat(deltaTime)
            }
            
            undoManager?.registerUndo(withTarget: self) { model in
                if model.decrementTime(deltaTime, selectedPointIndices: selectedPointIndices, undoManager: undoManager) {
                    model.graphicalArrayDelegate?.graphicalArraySelectionTimeChanged()
                }
            }
            
            return true
        }
        
        return false
    }
    
    func decrementTime(_ deltaTime: Double, selectedPointIndices: Set<Int>, undoManager: UndoManager?) -> Bool {
        var set = selectedPointIndices
        
            // first and last are never incremented
        set.remove(0)
        set.remove(points.count-1)
        
        let sortedIndices = Array(set).sorted()
                
        var indices:[Int] = []
        
        for i in sortedIndices {
            
            if points.isValid(index: i), points.isValid(index: i-1) {
                let valueToCompare = (set.contains(i-1) ? max(0,points[i-1].x - CGFloat(deltaTime)) :  points[i-1].x)
                
                if points[i].x - CGFloat(deltaTime) > valueToCompare {
                    indices.append(i)
                }
            }
        }
        
        if indices.count > 0 {
            
            if speakerOn, sortedIndices.count == 1 {
                playAudioIndex(sortedIndices[0])
            }
            
            for i in indices {
                points[i].x -= CGFloat(deltaTime)
            }
            
            undoManager?.registerUndo(withTarget: self) { model in
                if model.incrementTime(deltaTime, selectedPointIndices: selectedPointIndices, undoManager: undoManager) {
                    model.graphicalArrayDelegate?.graphicalArraySelectionTimeChanged()
                }
            }
            
            return true
        }
        
        return false
    }
    
    func incrementFrequency(_ deltaFrequency: Double, selectedPointIndices: Set<Int>, undoManager: UndoManager?) -> Bool {
        
        let sortedIndices = Array(selectedPointIndices).sorted()
        
        var indices:[Int] = []
        
        for i in sortedIndices {
            if points.isValid(index: i), points[i].y + CGFloat(deltaFrequency) <= maxFrequency  {
                indices.append(i)
            }
        }
        
        if indices.count > 0 {
            if speakerOn, sortedIndices.count == 1 {
                playAudioIndex(sortedIndices[0])
            }
            
            for i in indices {
                points[i].y += CGFloat(deltaFrequency)
            }
            
            undoManager?.registerUndo(withTarget: self) { model in
                if model.decrementFrequency(deltaFrequency, selectedPointIndices: selectedPointIndices, undoManager: undoManager) {
                    model.graphicalArrayDelegate?.graphicalArraySelectionFrequencyChanged()
                }
            }
            
            return true
        }
        
        return false
    }
    
    func decrementFrequency(_ deltaFrequency: Double, selectedPointIndices: Set<Int>, undoManager: UndoManager?) -> Bool {
        
        let sortedIndices = Array(selectedPointIndices).sorted()
        
        var indices:[Int] = []
        
        for i in sortedIndices {
            if points.isValid(index: i), points[i].y - CGFloat(deltaFrequency) >= minFrequency  {
                indices.append(i)
            }
        }
        
        if indices.count > 0 {
            if speakerOn, sortedIndices.count == 1 {
                playAudioIndex(sortedIndices[0])
            }
            
            for i in indices {
                points[i].y -= CGFloat(deltaFrequency)
            }
            
            undoManager?.registerUndo(withTarget: self) { model in
                if model.incrementFrequency(deltaFrequency, selectedPointIndices: selectedPointIndices, undoManager: undoManager) {
                    model.graphicalArrayDelegate?.graphicalArraySelectionFrequencyChanged()
                }
            }
            
            return true
        }
        
        return false
    }
    
    func moveSelectionLeft() {
        guard !selectedPointIndices.isEmpty else {
            selectedPointIndices.insert(points.count-1) // select last
            return // Nothing to move
        }
        
        let maxIndex = points.count - 1 // Maximum valid index in array
        
        let newIndices = selectedPointIndices.map { index in
            var newIndex = index - 1
            if newIndex < 0 {
                newIndex = maxIndex // Wrap around to the end
            }
            return newIndex
        }
        
        selectedPointIndices = Set(newIndices) // Convert the array back to a set
        
        if speakerOn, selectedPointIndices.count == 1, let firstIndex = selectedPointIndices.first {
            playAudioIndex(firstIndex)
        }
    }
    
    func moveSelectionRight() {
        guard !selectedPointIndices.isEmpty else {
            selectedPointIndices.insert(0) // select first
            return // Nothing to move
        }
        
        let maxIndex = points.count - 1 // Maximum valid index in array
        
        let newIndices = selectedPointIndices.map { index in
            var newIndex = index + 1
            if newIndex > maxIndex {
                newIndex = 0 // Wrap around to the beginning
            }
            return newIndex
        }
        
        selectedPointIndices = Set(newIndices) // Convert the array back to a set
        
        if speakerOn, selectedPointIndices.count == 1, let firstIndex = selectedPointIndices.first {
            playAudioIndex(firstIndex)
        }
    }
    
        // selection equalization
    
    func equalizeSelection(_ type:EqualizationType, undoManager: UndoManager?) -> Bool {
        
        var changed: Bool
        
        let originalPoints = points
        
        switch type {
            case .average:
                changed = replacePointsWithAverageY(in: &points, using: selectedPointIndices)
            case .minimum:
                changed = replacePointsWithMinimumY(in: &points, using: selectedPointIndices)
            case .maximum:
                changed = replacePointsWithMaximumY(in: &points, using: selectedPointIndices)
            case .first:
                changed = replacePointsWithFirstY(in: &points, using: selectedPointIndices)
            case .last:
                changed = replacePointsWithLastY(in: &points, using: selectedPointIndices)
            case .selectedNote:
                changed = replacePointsWithSelectedNoteFrequency(in: &points, using: selectedPointIndices)
            case .equalSpacedTime:
                changed = replaceSelectedPointsWithEqualTimeSpacing(in: &points, using: selectedPointIndices)
        }
        
    
        if changed {
                        
            undoManager?.registerUndo(withTarget: self) { model in
                
                model.points = originalPoints
                model.graphicalArrayDelegate?.graphicalArraySelectionFrequencyChanged()
                
                undoManager?.registerUndo(withTarget: self) { model in
                    let _ = model.equalizeSelection(type, undoManager: undoManager)
                    model.graphicalArrayDelegate?.graphicalArraySelectionFrequencyChanged()
                }
            }
        }
        
        return changed
    }
    
    func replacePointsWithFrequency(in points: inout [CGPoint], frequency:Double, using selectedPointIndices: Set<Int>) -> Bool {
    
        var changed = false
        
        for index in selectedPointIndices {
            if index < points.count {
                points[index] = CGPoint(x: points[index].x, y: frequency)
                changed = true
            }
        }
        
        return changed
    }
    
    func replacePointsWithAverageY(in points: inout [CGPoint], using selectedPointIndices: Set<Int>) -> Bool {
            // Calculate the average y-coordinate for selected points
        var totalY: CGFloat = 0.0
        var count: CGFloat = 0.0
        
        for index in selectedPointIndices {
            if index < points.count {
                totalY += points[index].y
                count += 1.0
            }
        }
        
        guard count > 0 else {
                // No points to update or divide by zero error
            return false
        }
        
        let averageY = totalY / count
        
        return replacePointsWithFrequency(in: &points, frequency: averageY, using: selectedPointIndices)
    }
    
    func replacePointsWithMinimumY(in points: inout [CGPoint], using selectedPointIndices: Set<Int>) -> Bool {
            // Find the minimum y-coordinate among selected points
        var minPointY: CGFloat? = nil
        
        for index in selectedPointIndices {
            if index < points.count {
                let y = points[index].y
                if minPointY == nil || y < minPointY! {
                    minPointY = y
                }
            }
        }
        
        guard let minY = minPointY else {
                // No valid points to update
            return false
        }
        
        return replacePointsWithFrequency(in: &points, frequency: minY, using: selectedPointIndices)
    }
    
    func replacePointsWithMaximumY(in points: inout [CGPoint], using selectedPointIndices: Set<Int>) -> Bool {
            // Find the maximum y-coordinate among selected points
        var maxPointY: CGFloat? = nil
        
        for index in selectedPointIndices {
            if index < points.count {
                let y = points[index].y
                if maxPointY == nil || y > maxPointY! {
                    maxPointY = y
                }
            }
        }
        
        guard let maxY = maxPointY else {
                // No valid points to update
            return false
        }
        
        return replacePointsWithFrequency(in: &points, frequency: maxY, using: selectedPointIndices)
    }
    
    func replacePointsWithFirstY(in points: inout [CGPoint], using selectedPointIndices: Set<Int>) -> Bool {
            // Sort the selectedPointIndices to ensure consistent behavior
        let sortedIndices = selectedPointIndices.sorted()
        
        var firstPointY: CGFloat? = nil
        
        if let firstIndex = sortedIndices.first, firstIndex <  points.count {
            firstPointY = points[firstIndex].y
        }
        
        guard let firstY = firstPointY else {
                // No valid points to update
            return false
        }
        
        return replacePointsWithFrequency(in: &points, frequency: firstY, using: selectedPointIndices)
    }
    
    func replacePointsWithLastY(in points: inout [CGPoint], using selectedPointIndices: Set<Int>) -> Bool {
            // Sort the selectedPointIndices to ensure consistent behavior
        let sortedIndices = selectedPointIndices.sorted()
        
        var lastPointY: CGFloat? = nil
        
        if let lastIndex = sortedIndices.last, lastIndex < points.count {
            lastPointY = points[lastIndex].y
        }
        
        guard let lastY = lastPointY else {
                // No valid points to update
            return false
        }
        
        return replacePointsWithFrequency(in: &points, frequency: lastY, using: selectedPointIndices)
    }
    
    // also used by `Set Note`
    func replacePointsWithSelectedNoteFrequency(in points: inout [CGPoint], using selectedPointIndices: Set<Int>) -> Bool {
        
        let frequencyRange:ClosedRange<Double> = minFrequency...maxFrequency
        
        guard let selectedNoteFrequency = selectedNoteFrequency, frequencyRange.contains(selectedNoteFrequency) else {
            return false
        }
        
        // only if the selected frequecy is within the selected frequency range
        for index in selectedPointIndices {
            if index < points.count {
                let y = points[index].y
                if y < minFrequency || y > maxFrequency {
                    return false
                }
            }
        }
        
        return replacePointsWithFrequency(in: &points, frequency: selectedNoteFrequency, using: selectedPointIndices)
    }
    
    func replacePointsFrequencyWithClosestNoteFrequency(undoManager: UndoManager?) -> Bool {
        
        var changed = false
        
        let originalPoints = points
        
        for index in selectedPointIndices {
            if index < points.count {
                let frequency = points[index].y
                if let closestNote = closesetNoteToFrequency(frequency, inRange: minFrequency...maxFrequency) {
                    points[index].y = closestNote
                    changed = true
                }
            }
        }
        
        if changed {
            
            undoManager?.registerUndo(withTarget: self) { model in
                
                model.points = originalPoints
                model.graphicalArrayDelegate?.graphicalArraySelectionFrequencyChanged()
                
                undoManager?.registerUndo(withTarget: self) { model in
                    let _ = model.replacePointsFrequencyWithClosestNoteFrequency(undoManager: undoManager)
                    model.graphicalArrayDelegate?.graphicalArraySelectionFrequencyChanged()
                }
            }
        }
        
        return changed
        
    }
    
    func findContiguousSubsets(_ selectedPointIndices: Set<Int>) -> [ClosedRange<Int>] {
        
        let sortedIndices = Array(selectedPointIndices).sorted()
        
        var contiguousSubsets: [ClosedRange<Int>] = []
        
        var start: Int? = nil
        var end: Int? = nil
        
        for index in sortedIndices {
            if start == nil {
                start = index
                end = index
            } else if index == end! + 1 {
                end = index
            } else {
                if end! - start! >= 2 {
                    contiguousSubsets.append(start!...end!)
                }
                start = index
                end = index
            }
        }
        
        if end != nil, end! - start! >= 2 {
            contiguousSubsets.append(start!...end!)
        }
        
        return contiguousSubsets
    }
    
    func replaceSelectedPointsWithEqualTimeSpacing(in points: inout [CGPoint], using selectedPointIndices: Set<Int>) -> Bool {
        
        func remapXCoordinatesEquallySpaced(_ P: inout [CGPoint], inRange c: ClosedRange<Int>) -> Bool {
            guard !P.isEmpty, c.count > 2, c.lowerBound >= 0, c.upperBound < P.count else {
                return false
            }
            
            var changed = false
            
            let count = c.upperBound - c.lowerBound + 1
            let startX = P[c.lowerBound].x
            let endX = P[c.upperBound].x
            let spacing = (endX - startX) / CGFloat(count - 1)
            
            for i in (c.lowerBound + 1)..<c.upperBound {
                let newValue = startX + CGFloat(i - c.lowerBound) * spacing
                if newValue != P[i].x {
                    P[i].x = newValue
                    changed = true
                }
            }
            
            return changed
        }
        
        func remapXCoordinatesEquallySpaced(points: inout [CGPoint], _ selectedPointIndices: Set<Int>) -> Bool {
            let contiguousSubsets = findContiguousSubsets(selectedPointIndices)
            
            guard contiguousSubsets.count > 0 else {
                return false
            }
            
            var changed = false
            
            for range in contiguousSubsets {
                if remapXCoordinatesEquallySpaced(&points, inRange: range) {
                    changed = true
                }
            }
            
            return changed
        }
        
        return remapXCoordinatesEquallySpaced(points: &points, selectedPointIndices)
    }
    
    func indexIsNotFirstOrLast(_ index:Int) -> Bool {
        return index != 0 && index != points.count - 1
    }
    
    func selectionContainsFirstOrLast() -> Bool {
        return selectedPointIndices.contains(0) || selectedPointIndices.contains(points.count - 1)
    }
    
    func firstSelectedFrequency() -> Double? {
        let sortedIndices = selectedPointIndices.sorted(by: >)
        if let firstIndex = sortedIndices.first {
            return points[firstIndex].y
        }
        return nil
    }
    
    // Note Picker
    func pointsWithSelectedNoteFrequency() -> Set<Int> {
        var indices = Set<Int>()
        
        for (index, point) in points.enumerated() {
            /* if point.y == selectedNoteFrequency { */ // not good, need roundTo
            if point.y.roundTo(2) == selectedNoteFrequency { // roundTo resolves number issue - Select Note 415.3 -> 415.29999999999995, but Select Note 1318.51 not a problem
                indices.insert(index)
            }
        }
        
        return indices
    }
    
    func noteForFrequency(frequency:Double) -> Double? {
        
        for key in pianoFrequencyToNoteMapping.keys {
            if CGFloat(frequency).roundTo(2) == key {
                return key
            }
        }
        
        return nil
    }
    
    func selectedPointsNoteFrequency() -> Double? {
        guard let sameFrequency = haveSameFrequency(points: points, selectedPointIndices: selectedPointIndices) else {
            return nil
        }
        
        return noteForFrequency(frequency: sameFrequency)
    }
    
    func haveSameFrequency(points: [CGPoint], selectedPointIndices: Set<Int>) -> Double? {
            
        var firstFrequency: Double? = nil
        
        for index in selectedPointIndices {
            guard index >= 0, index < points.count else {
                continue  // Skip invalid indices
            }
            
            let point = points[index]
            
            if firstFrequency == nil {
                firstFrequency = point.y
            } else {
                if point.y != firstFrequency {
                    return nil
                }
            }
        }
        
        return firstFrequency
    }

    
        // Function to delete a selected point
        // But can't delete first and last
    func deleteSelectedPoints(undoManager: UndoManager?) {
            // Sort the selected indices in descending order to prevent shifting
        let sortedIndices = selectedPointIndices.sorted(by: >)
        
        let savedSelectedPointIndices = selectedPointIndices
        let savedPoints = points
        
            // Remove the selected points in reverse order
        for index in sortedIndices {
            if indexIsNotFirstOrLast(index), points.isValid(index: index) {
                points.remove(at: index)
            }
        }
        
            // Clear the selectedPointIndices after removal
        selectedPointIndices.removeAll()
        
        undoManager?.registerUndo(withTarget: self) { model in
            model.points = savedPoints
            model.graphicalArrayDelegate?.graphicalArrayPointsDeleted()
            
            undoManager?.registerUndo(withTarget: self) { model in
                model.selectedPointIndices = savedSelectedPointIndices
                model.deleteSelectedPoints(undoManager: undoManager)
                model.graphicalArrayDelegate?.graphicalArrayPointAdded()
            }
        }
    }
    
        // From TonePlayer to play the tone corresponding to a points frequency
    func toneRamp(toneRampType:GAEToneRampType, duration:Double) -> ((Double)->Double)? {
        
        var scale:((Double)->Double)?
        
        switch toneRampType {
                
            case .none:
                scale = nil
            case .linear:
                scale = {t in 1 - (t / duration)}
            case .parabolic:
                scale = {t in pow(((t - duration)/duration), 2)}
            case .exponential:
                let a = log(Double(Int16.max)) / duration
                scale = {t in exp(-a * t)}
            case .triangle:
                scale = {t in ( t > duration / 2 ? 2 * (1 - (t / duration)): 2 * (t / duration))}
            case .sine:
                scale = {t in abs(sine(0.5 * t / duration)) }
        }
        
        return scale
    }
    
    // used to play the individual tones of points in the plot view
    func generateToneAudio(_ frequency: Double, _ duration: Double, _ toneRampType: GAEToneRampType, completion: @escaping (URL?) -> ()) {
        
        DispatchQueue.global().async { [weak self] in
            
            guard let self = self else {
                completion(nil)
                return
            }
            
            let outputURL = FileManager.documentsURL(filename: kGAEAudioExportName, subdirectoryName: kGAETemporarySubdirectoryName)!
            
            toneWriter.scale = toneRamp(toneRampType: toneRampType, duration: duration)
            
            toneWriter.saveComponentSamplesToFile(component: Component(type: WaveFunctionType.sine, frequency: frequency, amplitude: 1, offset: 0), duration: duration, destinationURL: outputURL) { url, message in
                
                self.toneWriter.scale = nil // practice to prevent retain cycle
                
                completion(url)
            }
        }
    }
 
    /*
     generateToneShapeAudio is used by the following functions:
     
        playToneShaperDocumentURL 
                - plays sample document tone shape audio  
     
        playToneShape 
                - for preview of the tone shape audio in the plot view
     
        exportToneShapeAudio 
                - write tone shape audio  to file
     */
    func generateToneShapeAudio(userIFCurve: [CGPoint], toneShaperScaleType:ToneShaperScaleType, duration:Double, echoOffsetTimeSeconds: Double, echoVolume: Double, completion: @escaping (URL?) -> ()) {
        
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
    
    // used to play selected points in the plot view
    func generateToneSequenceAudio(frequencies: [Double], completion: @escaping (URL?) -> ()) {
        
        DispatchQueue.global().async { [weak self] in
            
            guard let self = self else {
                completion(nil)
                return
            }
            
            let outputURL = FileManager.documentsURL(filename: kGAEAudioExportName, subdirectoryName: kGAETemporarySubdirectoryName)!
            
            toneWriter.scale = toneRamp(toneRampType: .none, duration: 0)
            
            let components = frequencies.map { frequency in
                Component(type: WaveFunctionType.sine, frequency: frequency, amplitude: 1, offset: 0)
            }
            
            // buffer size must adapt to duration if it is too small
            // saveComponentsSamplesToFile requires that : componentDuration >= Double(bufferSize) / Double(sampleRate)
            // But there should be at least 2 buffers for each, to mitigate clicks; see comments at saveComponentsSamplesToFile. That's why half_bufferSizeForDuration
            let sampleRate = 44100
            let bufferSizeForDuration = Int((componentDuration * Double(sampleRate)).rounded(FloatingPointRoundingRule.down))
            let half_bufferSizeForDuration = bufferSizeForDuration / 2 // at least 2 buffers per component to prevent clicks
            let bufferSize = max(min(half_bufferSizeForDuration, 8192), 128)
            
            toneWriter.saveComponentsSamplesToFile(components: components, shouldRamp: true, componentDuration: componentDuration, sampleRate: sampleRate, bufferSize: bufferSize, destinationURL: outputURL) { url, message in
                
                if let message = message {
                    print(message)
                }
                
                self.toneWriter.scale = nil // practice to prevent retain cycle
                
                completion(url)
            }
        }
    }
    
    func stopAudioPlayer() {
        indicesToPlay?.removeAll()
        avAudioPlayer?.stop()
        audioPlayer.stopPlayingAudio()
    }
    
    func playAudioURL(_ url:URL) {
        
        do {
            avAudioPlayer?.stop()
            
            avAudioPlayer = try AVAudioPlayer(contentsOf: url)         
            
            if let avAudioPlayer = avAudioPlayer {
                avAudioPlayer.delegate = self // to invoke audioPlayerDidFinishPlaying
                avAudioPlayer.prepareToPlay()
                avAudioPlayer.play()
            }
            
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    func playAudioFrequency(_ frequency:Double) {
        generateToneAudio(frequency, componentDuration, GAEToneRampType.sine) { [weak self] url in
            if let url = url {
                self?.playAudioURL(url)
            }
            else {
                print("Error - Tone not exported.")
            }
        }
    }
    
    func playAudioIndex(_ index:Int) {
        let frequency = self.points[index].y
        playAudioFrequency(frequency)
    }
    
    func playToneShape() {
        
        isPreparingToPlay = true
        
        let userIFCurve:[CGPoint] = GraphicalArrayModel.userIFCurve(self.fidelity, points: points)
        
        generateToneShapeAudio(userIFCurve: userIFCurve, toneShaperScaleType: self.scaleType, duration: self.duration, echoOffsetTimeSeconds: self.echoOffsetTimeSeconds, echoVolume: self.echoVolume) { [weak self] url in
            
            guard let self = self else {
                return
            }
            
            DispatchQueue.main.async {
                self.isPreparingToPlay = false
                
                if let url = url {
                    self.plotAudioObservable.asset = AVAsset(url: url)
                }
                
            }
            
            if let url = url {
                let _ = audioPlayer.playAudioURL(url)
            }
            else {
                print("Error - audio not played.")
            }
        }
    }
    
    func playAudioSelectedIndices() {
        self.indicesToPlay = selectedPointIndices.sorted()
        playFirstIndexOfIndicesToPlay()
    }
    
    /*
        Converts the x-coordinates of `points` to an array of integer valued indices (but with actual CGFloat values)
     */
    class func userIFCurve(_ N:Int, points:[CGPoint]) -> [CGPoint] {
        
        guard let firstPoint = points.first, let lastPoint = points.last else {
            return []
        }
        
        let minX = firstPoint.x
        let maxX = lastPoint.x
        
        let scaleFactor = CGFloat(N) / (maxX - minX)
        
            // Map the points to integers in the [0, N] interval
        let scaledPoints = points.map { point in
            let scaledX = Int((point.x - minX) * scaleFactor)
            return CGPoint(x: CGFloat(scaledX), y: point.y)
        }
        
        return scaledPoints
    }
    
    func insetForLabelType(_ labelType:GAELabelType) -> Double {
        switch labelType {
            case .none:
                return 25.0
            case .frequency:
                return 50.0
            case .frequencyAndNote:
                return 50.0
        }
    }
    
    func saveToneShapeImageToPhotos(completion: @escaping (Bool) -> ()) {
        
        let inset = insetForLabelType(labelType)
        
        SaveGraphicalArrayModelDataToPhotos(size: CGSize(width: kExportImageWidth, height: kExportImageHeight), scale: kExportImageScale, data: GraphicalArrayModelData(points: points, duration: duration, minFrequency: minFrequency, maxFrequency: maxFrequency), inset: inset, labelType: labelType) { result in
            completion(result)
        }

    }
    
    // write tone shape audio to a file
    func exportToneShapeAudio(errorHandler: @escaping () -> Void) {
        isExporting = true
        
        let userIFCurve:[CGPoint] = GraphicalArrayModel.userIFCurve(self.fidelity, points: points)
        
        generateToneShapeAudio(userIFCurve: userIFCurve, toneShaperScaleType: self.scaleType, duration: self.duration, echoOffsetTimeSeconds: self.echoOffsetTimeSeconds, echoVolume: self.echoVolume) { [weak self] url in
            
            guard let self = self else {
                return
            }
            
            if let url = url {
                
                self.audioDocument = AudioDocument(url: url, preferredFilename: graphicalArrayDelegate?.graphicalArrayAudioExportFilename())
                
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.showAudioExporter = true
                }
                
                    // print its duration
                let asset = AVAsset(url: url)
                
                Task {
                    let durationText = await asset.durationText
                    print("ToneWriter : audio duration = \(durationText)")
                }
                
                Task {
                    do {
                        let duration = try await asset.load(.duration)
                        print("ToneWriter : audio duration seconds = \(duration.seconds)")
                    }
                    catch {
                        print("\(error)")
                    }
                }
                
            }
            else {
                print("Error - audio not exported.")
                
                DispatchQueue.main.async {
                    self.isExporting = false
                    errorHandler()
                }
            }
            
        }
        
    }
    
    func exportSelectedToneSequenceAudio(errorHandler: @escaping () -> Void) {
        isExporting = true
        
        var frequencies:[Double] = []
        
        let indicesArray = selectedPointIndices.sorted()
        
        for index in indicesArray {
            frequencies.append(self.points[index].y) 
        }
        
        generateToneSequenceAudio(frequencies: frequencies) { [weak self] url in
            
            guard let self = self else {
                return
            }
            
            if let url = url {
                
                self.audioDocument = AudioDocument(url: url, preferredFilename: graphicalArrayDelegate?.graphicalArrayAudioExportFilename())
                
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.showAudioExporter = true
                }
                
                // print its duration
                let asset = AVAsset(url: url)
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
                print("Error - audio not exported.")
                
                DispatchQueue.main.async {
                    self.isExporting = false
                    errorHandler()
                }
            }
        }
    }
    
    func playFirstIndexOfIndicesToPlay(_ animated: Bool = true) {
        if let indicesToPlay = self.indicesToPlay, indicesToPlay.count > 0, let index = self.indicesToPlay?.removeFirst() {
            
            if animated {
                selectedPointIndices.remove(index)
            }
            
            playAudioIndex(index)
            
            if animated {
                DispatchQueue.main.asyncAfter(deadline: .now() + componentDuration) { [weak self] in
                    self?.selectedPointIndices.insert(index)
                }
            }
            
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            playFirstIndexOfIndicesToPlay()
        } else {
            indicesToPlay?.removeAll()
        }
    }
    
        // AudioPlayerDelegate
        // set delegate in init!
    func audioPlayDone(_ player: AudioPlayer?, percent: CGFloat) {
        indicatorPercent = 0
        
        plotAudioObservable.indicatorPercent = 0
    }
    
        // AudioPlayerDelegate
        // When loop count > 1, need to adjust indicatorPercent for each loop 
    func audioPlayProgress(_ player: AudioPlayer?, percent: CGFloat) {
        indicatorPercent = (percent * Double(loopCount)).truncatingRemainder(dividingBy: 1)
        
        plotAudioObservable.indicatorPercent = percent
    }
    
    func plotAudioDragChanged(_ value: CGFloat) {
        audioPlayer.stopPlayingAudio()
        
        indicatorPercent = (value * Double(loopCount)).truncatingRemainder(dividingBy: 1)
    }
    
    func plotAudioDragEnded(_ value: CGFloat) {
        audioPlayer.play(percent: value)
        
       // indicatorPercent = (value * Double(loopCount)).truncatingRemainder(dividingBy: 1)
    }
    
    func plotAudioDidFinishPlotting() {
        
    }
}
