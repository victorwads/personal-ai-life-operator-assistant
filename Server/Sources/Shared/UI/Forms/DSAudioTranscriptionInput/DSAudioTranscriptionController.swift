import Foundation
import SwiftUI

@MainActor
protocol DSAudioTranscriptionController: ObservableObject {
    var status: DSAudioTranscriptionStatus { get }
    var livePartialText: String { get }
    var processingSegments: [DSAudioTranscriptionSegment] { get }

    var totalSegmentCount: Int { get }
    var processingSegmentCount: Int { get }
    var completedSegmentCount: Int { get }

    func start()
    func stop()
    func cancel()

    func consumeCompletedSegmentTextToAppend() -> String?
}
