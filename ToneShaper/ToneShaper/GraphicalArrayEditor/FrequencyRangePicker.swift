//
//  FrequencyRangePicker.swift
//  GraphicalArrayEditor
//
//  Created by Joseph Pagliaro on 9/1/23.
//

import SwiftUI

func mapRangeValue(_ x: Double, fromRange r: ClosedRange<Double>, toRange s: ClosedRange<Double>) -> Double {
    let rLength = r.upperBound - r.lowerBound
    let sLength = s.upperBound - s.lowerBound
    
    let normalizedX = (x - r.lowerBound) / rLength
    let mappedValue = normalizedX * sLength + s.lowerBound
    
    return mappedValue
}

func frequencyRange() -> ClosedRange<Double> {
    return lowestFrequency()...highestFrequency()
}

func frequencySliderRange() -> ClosedRange<Double> {
    return pianoKeyForFrequency(lowestFrequency())...pianoKeyForFrequency(highestFrequency())
}

    // Sample Use to pick frquencies in range 20...22050 with non-linear frequency mapping
let kIncrementCount = Int(frequencySliderRange().upperBound)
let SLIDER_INCREMENT_RANGE:ClosedRange<Double> = 1...Double(kIncrementCount)
let SLIDER_FREQUENCY_RANGE:ClosedRange<Double> = frequencySliderRange()

struct FrequencyRangePicker: View {
    
    @ObservedObject var viewModel:GraphicalArrayModel
    
    @Environment(\.undoManager) var undoManager
    
    @State var sliderPosition: ClosedRange<Double> = SLIDER_INCREMENT_RANGE
    
    var rangedSliderViewChanged:(()->())?
    
        // map slider range to desired frequency range
        // range slider -> frequencySliderRange() -> frequencyRange()
    func frequencyRangeFromSliderRange() -> ClosedRange<Double> {
        
        let mappedRange = mapRangeValue(sliderPosition.lowerBound, fromRange: SLIDER_INCREMENT_RANGE, toRange: SLIDER_FREQUENCY_RANGE)...mapRangeValue(sliderPosition.upperBound, fromRange: SLIDER_INCREMENT_RANGE, toRange: SLIDER_FREQUENCY_RANGE)
        
        return frequencyForPianoKey(mappedRange.lowerBound)...frequencyForPianoKey(mappedRange.upperBound)
    }
    
    func sliderRangeFromFrequencyRange(viewModel: GraphicalArrayModel) -> ClosedRange<Double> {
        
        let mappedRange = mapRangeValue(pianoKeyForFrequency(viewModel.minFrequency), fromRange: SLIDER_FREQUENCY_RANGE, toRange: SLIDER_INCREMENT_RANGE )...mapRangeValue(pianoKeyForFrequency(viewModel.maxFrequency), fromRange: SLIDER_FREQUENCY_RANGE, toRange: SLIDER_INCREMENT_RANGE)
        
        return mappedRange
    }
    
    var rangeButtonsView: some View {
        HStack {
            
            Button(action: {
                
                let oldFrequencyRange:ClosedRange<Double> = viewModel.minFrequency...viewModel.maxFrequency
                
                viewModel.minFrequency = lowestFrequency()
                viewModel.maxFrequency = highestFrequency()
                
                viewModel.registerUndoForFrequencyRangeSlider(oldRange: oldFrequencyRange, undoManager: undoManager)
                viewModel.graphicalArrayDelegate?.graphicalArrayFrequencyRangeChanged()
            }) {
                HStack {
                    Text("Human Range")
                        .foregroundColor(.blue)
                    Image(systemName: "figure.stand")
                    
                }
            }
            
            Spacer()
            
            Button(action: {
                
                let oldFrequencyRange:ClosedRange<Double> = viewModel.minFrequency...viewModel.maxFrequency
                
                viewModel.minFrequency = smallestPianoFrequency
                viewModel.maxFrequency = largestPianoFrequency
                
                viewModel.registerUndoForFrequencyRangeSlider(oldRange: oldFrequencyRange, undoManager: undoManager)
                viewModel.graphicalArrayDelegate?.graphicalArrayFrequencyRangeChanged()
            }) {
                HStack {
                    Text("Piano Range")
                        .foregroundColor(.blue)
                    Image(systemName: "pianokeys")
                }
            }
        }
    }
    
    var rangeView: some View {
        VStack {
            
            Text("\(String(format: kRangePrecisonDisplay, frequencyRangeFromSliderRange().lowerBound))...\(String(format: kRangePrecisonDisplay, frequencyRangeFromSliderRange().upperBound))")
            
            RangedSliderView(incrementCount: kIncrementCount, incrementCountRange: $sliderPosition, rangedSliderViewChanged: rangedSliderViewChanged) {
                frequencyRangeFromSliderRange()
            }
        }
        .frame(height:80)
        .onChange(of: sliderPosition) { _ in
            viewModel.minFrequency = frequencyRangeFromSliderRange().lowerBound
            viewModel.maxFrequency = frequencyRangeFromSliderRange().upperBound
        }
        .onChange(of: viewModel.minFrequency) { _ in
            sliderPosition = sliderRangeFromFrequencyRange(viewModel: viewModel)
        }
        .onChange(of: viewModel.maxFrequency) { _ in
            sliderPosition = sliderRangeFromFrequencyRange(viewModel: viewModel)
        }
        .onChange(of: viewModel, perform: { newViewModel in
            sliderPosition = sliderRangeFromFrequencyRange(viewModel: newViewModel)
        })
        .onAppear {
            sliderPosition = sliderRangeFromFrequencyRange(viewModel: viewModel)
        }
    }
    
    var body: some View {
        VStack {
            rangeView
            rangeButtonsView
        }
    }
}

/*
 Note : the picker is initialized to a subrange
 */

struct FrequencyRangePickerWrapper: View {
    
    @StateObject var viewModel = GraphicalArrayModel(data: kDefaultModelData)
    
    var body: some View {
        FrequencyRangePicker(viewModel: viewModel).padding()
            .onChange(of: viewModel.minFrequency) { newValue in
                print("\(String(format: kRangePrecisonDisplay, newValue))")
            }
            .onChange(of: viewModel.maxFrequency) { newValue in
                print("\(String(format: kRangePrecisonDisplay, newValue))")
            }
    }
}

struct FrequencyRangePicker_Previews: PreviewProvider {
    static var previews: some View {
        FrequencyRangePickerWrapper()
    }
}

