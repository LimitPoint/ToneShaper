![ToneShaper](https://www.limit-point.com/assets/images/ToneShaper.jpg)
# ToneShaper
## Audio samples are generated with numerical integration of user defined instantaneous frequency curves.  

The associated Xcode project implements an iOS and macOS SwiftUI app that enables users to draw [instantaneous frequency] values to define a function of time, `v(t)`. The function `v(t)` is [numerically integrated] with the Accelerate method [vDSP_vtrapzD] to generate a time varying phase argument `x(t)` of a periodic function `s(t)`. The composition `s(x(t))` is [sampled] at a [sufficient rate] to produce audio samples for playing or writing to a file. 

### App Features

The instantaneous frequency function `v(t)` is defined through two editing views. 

The width of each view corresponds to a selected time range `[0, duration]`, while the height corresponds to a selected frequency range `[minFrequency, maxFrequency]`.

**Plot View:** Users can _tap_ within the view to select a series of points, subsequently subjected to [linear interpolation] by the [vDSP.linearInterpolate] function.

![frequency_plot](http://www.limitpointstore.com/products/toneshaper/images/frequency_plot.png)

**Draw View:** Alternatively _drag_ within this view to select a series of points for transition to the Plot View.

![drag_to_draw](http://www.limitpointstore.com/products/toneshaper/images/drag_to_draw.gif)
  
Audio generation parameters are duration, frequency range, amplitude scaling, wave type, echo and fidelity, and are stored in documents. In-place [document] editing supports [undo and redo]. The samples library is a collection of built-in documents with parameter presets for starting points.

![samples](http://www.limitpointstore.com/products/toneshaper/images/library_button.gif)

Continuous audio play with [AVAudioEngine] provides feedback during experimentation with sound parameters before saving the sound as multiple cycles of the duration to a [WAV] file. 

[vDSP_vtrapzD]: https://developer.apple.com/documentation/accelerate/1450678-vdsp_vtrapz
[vDSP.linearInterpolate]: https://developer.apple.com/documentation/accelerate/vdsp/3600628-linearinterpolate
[AVAudioEngine]: https://developer.apple.com/documentation/avfaudio/avaudiosourcenode
[WAV]: https://en.wikipedia.org/wiki/WAV
[instantaneous frequency]: https://www.limit-point.com/blog/2023/tone-shaper/#InstantaneousFrequency
[numerically integrated]: https://www.limit-point.com/blog/2023/tone-shaper/#Numerical-Integration
[sampled]: https://www.limit-point.com/blog/2023/tone-shaper/#SamplingSignals
[sufficient rate]: https://www.limit-point.com/blog/2023/tone-shaper/#Nyquist-Shannon-sampling-theorem
[document]: https://developer.apple.com/documentation/swiftui/building_a_document-based_app_with_swiftui
[undo and redo]: https://developer.apple.com/documentation/swiftui/environmentvalues/undomanager
[linear interpolation]: https://developer.apple.com/documentation/accelerate/using_linear_interpolation_to_construct_new_data_points
