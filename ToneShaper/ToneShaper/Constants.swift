//
//  Constants.swift
//  ToneShaper
//
//  Created by Joseph Pagliaro on 9/15/23.
//

import SwiftUI

let limitPointURL = "https://www.limit-point.com/"
let helpURL = "https://www.limitpointstore.com/products/toneshaper/help/"
let kToneShaperURL = "https://www.limit-point.com/blog/2023/tone-shaper/"

// export image
let kExportImageWidth = 1024
let kExportImageHeight = 512
let kExportImageScale = 4.0

let kUserIFCurvePointCount = 500

let fouierSeriesTermCount = 3
let defaultComponent = Component(type: WaveFunctionType.sine, frequency: 440.0, amplitude: 0.1, offset: 0.0)

let creamsicleColor = Color(red: 255/255, green: 247/255, blue: 229/255)
let paleSkyBlueColor = Color(red: 236/255, green: 245/255, blue: 255/255)
let subtleMistColor = Color(red: 0.949, green: 0.949, blue: 0.97)
let livelyLavenderColor = Color(red: 269/255, green: 222/255, blue: 253/255)

let kDefaultLabelType = GAELabelType.frequencyAndNote
let kDefaultScaleType = ToneShaperScaleType.sine
let kDefaultComponentType = WaveFunctionType.sine

let kSplashScreenText = "Very high and very low frequencies may be difficult to hear.\n\nIf the volume is set very high to compensate then it may be too high for other frequencies, and that can damage your hearing.\n\nSet the volume low initially and increase it with care.\n\nCreate cycles with tone shapes of smoothly varying frequency by plotting frequency at specific times.\n\nTap the library button to pick from a selection of sample tone shapes to get started.\n\nTap in the plot view to add points with coordinates (time,frequency). Drag to move points, but limited by the neighbors time.\n\nAlternatively, drag in the draw tab to add points, then apply them to set the points in the plot view.\n\nAdjust the frequency range slider to limit the bandwidth.\n\nAdjust the duration slider to specify the cycle period.\n\nFinally, in the export view you can save the audio to a WAV file with a chosen number of cycles. The duration of the audio is limited by the maximum duration, which therefore also limits the number of cycles in the audio file."


let kEchoOffsetOptionNote = "Since the echo offset is bounded by the tone shape duration, when the duration changes the echo offset will be updated so that its ratio with the duration remains the same."

let kAmplitudeScalingNote = "Amplitude scaling can mitigate audio clicks due to frequency discontinuity between cycles."
let kComponentTypeNote = "The wave function type for generating audio samples."
let kAudioFeedbackNote = "Audio feedback occurs during selecting and dragging points in the plot view."
