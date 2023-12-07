//
//  PianoNoteToFrequencyMapping.swift
//  TonePlayer
//
//  Created by Joseph Pagliaro on 2/18/23.
//

import Foundation

    // roundTo fixes 932.3299999999999 for 932.33
extension CGFloat {
    func roundTo(_ places:Int) -> CGFloat {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

    // roundTo fixes 932.3299999999999 for 932.33
extension Double {
    func roundTo(_ places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

extension String {
    func substringBeforeSlash() -> String {
        let components = self.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
        if let firstComponent = components.first {
            return String(firstComponent)
        } else {
            return ""
        }
    }
}

func replaceStrings(_ A: [(String, Any)], replaceString: (String) -> String) -> [(String, Any)] {
    var B: [(String, Any)] = []
    for tuple in A {
        let newString = replaceString(tuple.0)
        let newTuple = (newString, tuple.1)
        B.append(newTuple)
    }
    return B
}

func mergeDicts<T, U>(_ dicts: [T: U]...) -> [T: U] {
    var mergedDict = [T: U]()
    for dict in dicts {
        for (key, value) in dict {
            mergedDict[key] = value
        }
    }
    return mergedDict
}

func sortedKeyValuePairs(from dictionary: [String: Any]) -> [(key: String, value: Any)] {
    let sortedKeys = dictionary.keys.sorted()
    return sortedKeys.map { (key: $0, value: dictionary[$0]!) }
}

func sortDictionaryByValue(dictionary: [String: Double]) -> [(String, Double)] {
    let sortedByValue = dictionary.sorted { $0.value < $1.value }
    return sortedByValue.map { ($0.key, $0.value) }
}

func invertDictionary(_ dict: [String: Double]) -> [Double: String] {
    var invertedDict = [Double: String]()
    for (key, value) in dict {
        invertedDict[value] = key
    }
    return invertedDict
}

func findMaxMinNoteFrequencyValues(in dict: [String: Double]) -> (min: (note: String, frequency: Double), max: (note: String, frequency: Double)) {
    
    var largestFrequency = Double.leastNormalMagnitude
    var largestNote = ""
    
    var smallestFrequency = Double.greatestFiniteMagnitude
    var smallesNote = ""
    
    for (key, value) in dict {
        if value > largestFrequency {
            largestFrequency = value
            largestNote = key
        }
        if value < smallestFrequency {
            smallestFrequency = value
            smallesNote = key
        }
    }
    return (min: (note: smallesNote, frequency: smallestFrequency), max: (note: largestNote, frequency: largestFrequency))
}

let zerothOctaveKeys: [String: Double] = [
    "A0": 27.50,
    "A#0/Bb0": 29.14,
    "B0": 30.87,   
]

let firstOctaveKeys: [String: Double] = [
    "C1": 32.70,
    "C#1/Db1": 34.65,
    "D1": 36.71,
    "D#1/Eb1": 38.89,
    "E1": 41.20,
    "F1": 43.65,
    "F#1/Gb1": 46.25,
    "G1": 49.00,
    "G#1/Ab1": 51.91,
    "A1": 55.00,
    "A#1/Bb1": 58.27,
    "B1": 61.74,
]

let secondOctaveKeys: [String: Double] = [
    "C2": 65.41,
    "C#2/Db2": 69.30,
    "D2": 73.42,
    "D#2/Eb2": 77.78,
    "E2": 82.41,
    "F2": 87.31,
    "F#2/Gb2": 92.50,
    "G2": 98.00,
    "G#2/Ab2": 103.83,
    "A2": 110.00,
    "A#2/Bb2": 116.54,
    "B2": 123.47   
]

let thirdOctaveKeys: [String: Double] = [
    "C3": 130.81,
    "C#3/Db3": 138.59,
    "D3": 146.83,
    "D#3/Eb3": 155.56,
    "E3": 164.81,
    "F3": 174.61,
    "F#3/Gb3": 185.00,
    "G3": 196.00,
    "G#3/Ab3": 207.65,
    "A3": 220.00,
    "A#3/Bb3": 233.08,
    "B3": 246.94  
]

let fourthOctaveKeys: [String: Double] = [
    "C4": 261.63,
    "C#4/Db4": 277.18,
    "D4": 293.66,
    "D#4/Eb4": 311.13,
    "E4": 329.63,
    "F4": 349.23,
    "F#4/Gb4": 369.99,
    "G4": 392.00,
    "G#4/Ab4": 415.30,
    "A4": 440.00,
    "A#4/Bb4": 466.16,
    "B4": 493.88   
]

let fifthOctaveKeys: [String: Double] = [
    "C5": 523.25,
    "C#5/Db5": 554.37,
    "D5": 587.33,
    "D#5/Eb5": 622.25,
    "E5": 659.25,
    "F5": 698.46,
    "F#5/Gb5": 739.99,
    "G5": 783.99,
    "G#5/Ab5": 830.61,
    "A5": 880.00,
    "A#5/Bb5": 932.33,
    "B5": 987.77   
]

let sixthOctaveKeys: [String: Double] = [
    "C6": 1046.50,
    "C#6/Db6": 1108.73,
    "D6": 1174.66,
    "D#6/Eb6": 1244.51,
    "E6": 1318.51,
    "F6": 1396.91,
    "F#6/Gb6": 1479.98,
    "G6": 1567.98,
    "G#6/Ab6": 1661.22,
    "A6": 1760.00,
    "A#6/Bb6": 1864.66,
    "B6": 1975.53
]

let seventhOctaveKeys: [String: Double] = [
    "C7": 2093.00,
    "C#7/Db7": 2217.46,
    "D7": 2349.32,
    "D#7/Eb7": 2489.02,
    "E7": 2637.02,
    "F7": 2793.83,
    "F#7/Gb7": 2959.96,
    "G7": 3135.96,
    "G#7/Ab7": 3322.44,
    "A7": 3520.00,
    "A#7/Bb7": 3729.31,
    "B7": 3951.07
]

let eighthOctaveKeys: [String: Double] = [
    "C8": 4186.01,
    "C#8/Db8": 4434.92,
    "D8": 4698.63,
    "D#8/Eb8": 4978.03,
    "E8": 5274.04,
    "F8": 5587.65,
    "F#8/Gb8": 5919.91,
    "G8": 6271.93,
    "G#8/Ab8": 6644.88,
    "A8": 7040.00,
    "A#8/Bb8": 7458.62,
    "B8": 7902.13
]

let pianoNoteToFrequencyMapping: [String: Double] = mergeDicts(zerothOctaveKeys, firstOctaveKeys, secondOctaveKeys, thirdOctaveKeys, fourthOctaveKeys, fifthOctaveKeys, sixthOctaveKeys, seventhOctaveKeys, eighthOctaveKeys)

let pianoNoteFrequenciesArray = sortDictionaryByValue(dictionary: pianoNoteToFrequencyMapping)

let pianoFrequencyToNoteMapping = invertDictionary(pianoNoteToFrequencyMapping)

let minMaxPianoNoteFrequencyValues = findMaxMinNoteFrequencyValues(in: pianoNoteToFrequencyMapping)

let smallestPianoNote = minMaxPianoNoteFrequencyValues.min.note
let smallestPianoFrequency = minMaxPianoNoteFrequencyValues.min.frequency

let largestPianoNote = minMaxPianoNoteFrequencyValues.max.note
let largestPianoFrequency = minMaxPianoNoteFrequencyValues.max.frequency

func OctavesArray() -> [[(note:String, frequency:Double)]] {
    return [
        replaceStrings(sortDictionaryByValue(dictionary: zerothOctaveKeys)) { note in
            note.substringBeforeSlash()
        } as! [(String, Double)],
        replaceStrings(sortDictionaryByValue(dictionary: firstOctaveKeys)) { note in
            note.substringBeforeSlash()
        } as! [(String, Double)],
        replaceStrings(sortDictionaryByValue(dictionary: secondOctaveKeys)) { note in
            note.substringBeforeSlash()
        } as! [(String, Double)],
        replaceStrings(sortDictionaryByValue(dictionary: thirdOctaveKeys)) { note in
            note.substringBeforeSlash()
        } as! [(String, Double)],
        replaceStrings(sortDictionaryByValue(dictionary: fourthOctaveKeys)) { note in
            note.substringBeforeSlash()
        } as! [(String, Double)],
        replaceStrings(sortDictionaryByValue(dictionary: fifthOctaveKeys)) { note in
            note.substringBeforeSlash()
        } as! [(String, Double)],
        replaceStrings(sortDictionaryByValue(dictionary: sixthOctaveKeys)) { note in
            note.substringBeforeSlash()
        } as! [(String, Double)],
        replaceStrings(sortDictionaryByValue(dictionary: seventhOctaveKeys)) { note in
            note.substringBeforeSlash()
        } as! [(String, Double)],
        replaceStrings(sortDictionaryByValue(dictionary: eighthOctaveKeys)) { note in
            note.substringBeforeSlash()
        } as! [(String, Double)]
    ]
}
 
// See Piano key frequencies at https://en.wikipedia.org/wiki/Piano_key_frequencies
func frequencyForPianoKey(_ x:Double) -> Double {
    return pow(2.0, ((x - Double(49)) / 12.0)) * 440.0
}

func pianoKeyForFrequency(_ x:Double) -> Double {
    return 12.0 * log2(x / 440.0) + 49.0
}

func closesetNoteToFrequency(_ frequency:Double, inRange:ClosedRange<Double>) -> Double? {
    
    var closestNote:Double?
    
    var smallestDifference = Double.infinity
    
    let roundedTo3 = frequency.roundTo(2) 
    var rangeRoundedTo3 = inRange
    
    if inRange.lowerBound.roundTo(2) <= inRange.upperBound.roundTo(2) {
        rangeRoundedTo3 = inRange.lowerBound.roundTo(2)...inRange.upperBound.roundTo(2) // roundTo fixes 932.3299999999999 for 932.33
    }
    
    for key in pianoFrequencyToNoteMapping.keys {
        if rangeRoundedTo3.contains(key) {
            let difference = abs(key - roundedTo3) // roundTo fixes 932.3299999999999 for 932.33
            if difference < smallestDifference {
                smallestDifference = difference
                closestNote = key
            } 
        }
    }
    
    return closestNote
}

func pianoNoteForFrequency(_ frequency:Double) -> String {
    
    var isExact = false
    
    let roundedTo3 = frequency.roundTo(2) // roundTo fixes 932.3299999999999 for 932.33
    
    guard roundedTo3 >= smallestPianoFrequency else {
        return "< \(smallestPianoNote)"
    }
    
    guard roundedTo3 <= largestPianoFrequency else {
        return "> \(largestPianoNote)"
    }
    
    var closestNote: String = ""
    var smallestDifference = Double.infinity
    
    for key in pianoFrequencyToNoteMapping.keys {
        let difference = abs(key - roundedTo3)
        if difference < smallestDifference {
            smallestDifference = difference
            closestNote = pianoFrequencyToNoteMapping[key]!
            if difference == 0 {
                isExact = true
            }
        }
    }
    
    if isExact == false {
        closestNote = "~\(closestNote)"
    }
    
    return closestNote
}

func frequencyIsNote(frequency:Double) -> Bool {
    
    for key in pianoFrequencyToNoteMapping.keys {
        if CGFloat(frequency).roundTo(2) == key { // roundTo fixes 932.3299999999999 for 932.33
            return true
        }
    }
    
    return false
}
