import AVFoundation
import Foundation

protocol VoiceActivityDetecting: AnyObject {
    var onSpeechStarted: (() -> Void)? { get set }
    var onSpeechEnded: (() -> Void)? { get set }

    var latestProbability: Float? { get }

    func start()
    func stop()
    func reset()
    func processAudioSamples(_ samples: [Float])
}
