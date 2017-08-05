

import Foundation
import AudioKit

class G8AudioKitWrapper: NSObject{
    
    //Variables for Audio audioAnalysis
    var microphone : AKMicrophone! // Device Microphone
    var amplitudeTracker: AKAmplitudeTracker! // Tracks the amplitude of the microphone
    var signalBooster: AKBooster! // boosts the signal
    var audioAnalysisTimer: Timer? // Continuously calls audioAnalysis function
    let amplitudeBuffSize = 10 // Smaller buffer will yield more amplitude responiveness and instability, higher value will respond slower but will be smoother
    var amplitudeBuffer: [Double] // This stores a rolling window of amplitude values, used to get average amplitude
    
    //Nodes
    var highPass: AKHighPassFilter?
    var lowPass: AKLowPassFilter?
    var reBalanced: AKBalancer?
    var silence: AKBooster?
    
    
    public var onAmplitudeUpdate: ((_ value: Float) -> ())?
    
    
    public override init() {
        // Initialize the audio buffer with zeros
        self.amplitudeBuffer = [Double](repeating: 0.0, count: amplitudeBuffSize)
        
        super.init()
    }
    /**
     Set up AudioKit Processing Pipeline and start the audio analysis.
     */
    public func startAudioAnalysis(){
        
        stopAudioAnalysis()
        
        // Settings
        AKSettings.bufferLength = .medium // Set's the audio signal buffer size
        do {
            try AKSettings.setSession(category: .playAndRecord)
        } catch {
            AKLog("Could not set session category.")
        }
        
        // ----------------
        // Input + Pipeline
        
        // Initialize the built-in Microphone
        microphone = AKMicrophone()
        
        // Pre-processing
        signalBooster = AKBooster(microphone)
        signalBooster.gain = 5.0 // When video recording starts, the signal gets boosted to the equivalent of 5.0, so we're setting it to 5.0 here and changing it to 1.0 when we start video recording.
        
        // Filter out anything outside human voice range
        highPass = AKHighPassFilter(signalBooster, cutoffFrequency: 55) // Lowered this a bit to be more sensitive to bass-drums
        
        lowPass = AKLowPassFilter(highPass, cutoffFrequency: 255)
        
        //  At this point you don't have much signal left, so you balance it against the original signal!
        reBalanced = AKBalancer(lowPass, comparator: signalBooster)
        
        // Track the amplitude of the rebalanced signal, we use this value for audio reactivity
        amplitudeTracker = AKAmplitudeTracker(reBalanced)
        
        // Mute the audio that gets routed to the device output, preventing feedback
        silence = AKBooster(amplitudeTracker, gain:0)
        
        // We need to complete the chain, routing silenced audio to the output
        AudioKit.output = silence
        
        // Start the chain and timer callback
        AudioKit.start()
        audioAnalysisTimer = Timer.scheduledTimer(timeInterval: 0.01,
                                                  target: self,
                                                  selector: #selector(audioAnalysis),
                                                  userInfo: nil,
                                                  repeats: true)
        // Put the timer on the main thread so UI updates don't interrupt
        RunLoop.main.add(audioAnalysisTimer!, forMode: RunLoopMode.commonModes)
    }
    
    // Call this when closing the app or going to background
    public func stopAudioAnalysis(){
        audioAnalysisTimer?.invalidate()
        AudioKit.disconnectAllInputs() // Disconnect all AudioKit components, so they can be relinked when we call startAudioAnalysis()
        AudioKit.stop()
        
    }
    
    // This is called on the audioAnalysisTimer
    func audioAnalysis(){
        writeToBuffer(val: amplitudeTracker.amplitude) // Write an amplitude value to the rolling buffer
        let val = getBufferAverage()
        onAmplitudeUpdate?(Float(val))
        
    }
    
    // Writes amplitude values to a rolling window buffer, writes to index 0 and pushes the previous values to the right, removes the last value to preserve buffer length.
    func writeToBuffer(val: Double) {
        for (index, _) in amplitudeBuffer.enumerated() {
            if (index == 0) {
                amplitudeBuffer.insert(val, at: 0)
                _ = amplitudeBuffer.popLast()
            }
            else if (index < amplitudeBuffer.count-1) {
                amplitudeBuffer.rearrange(from: index-1, to: index+1)
            }
        }
    }
    
    // Returns the average of the amplitudeBuffer, resulting in a smoother audio reactivity signal
    func getBufferAverage() -> Double {
        var avg:Double = 0.0
        for val in amplitudeBuffer {
            avg = avg + val
        }
        avg = avg / amplitudeBuffer.count
        return avg
    }
    
    
    
}
extension Array {
    mutating func rearrange(from: Int, to: Int) {
        precondition(from != to && indices.contains(from) && indices.contains(to), "invalid indexes")
        insert(remove(at: from), at: to)
    }
}
