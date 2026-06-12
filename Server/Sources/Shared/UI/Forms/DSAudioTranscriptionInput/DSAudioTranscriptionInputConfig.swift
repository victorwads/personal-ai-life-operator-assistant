import SwiftUI

enum DSAudioTranscriptionBadgeSurface: Equatable {
    case realtimeUnstable
    case queuedMuted
    case processingStrong

    static let defaultQueued: DSAudioTranscriptionBadgeSurface = .queuedMuted
    static let defaultProcessing: DSAudioTranscriptionBadgeSurface = .processingStrong
    static let defaultRealtime: DSAudioTranscriptionBadgeSurface = .realtimeUnstable
}

enum DSAudioTranscriptionRealtimeBadgeAccent: Equatable {
    case blue
    case green
}

struct DSAudioTranscriptionBadgePalette: Equatable {
    var queued: DSAudioTranscriptionBadgeSurface
    var processing: DSAudioTranscriptionBadgeSurface
    var realtime: DSAudioTranscriptionBadgeSurface
    var realtimeAccent: DSAudioTranscriptionRealtimeBadgeAccent

    init(
        queued: DSAudioTranscriptionBadgeSurface = .defaultQueued,
        processing: DSAudioTranscriptionBadgeSurface = .defaultProcessing,
        realtime: DSAudioTranscriptionBadgeSurface = .defaultRealtime,
        realtimeAccent: DSAudioTranscriptionRealtimeBadgeAccent = .blue
    ) {
        self.queued = queued
        self.processing = processing
        self.realtime = realtime
        self.realtimeAccent = realtimeAccent
    }

    static let `default` = DSAudioTranscriptionBadgePalette()
}

struct DSAudioTranscriptionInputConfig: Equatable {
    var minHeight: CGFloat
    var maxHeight: CGFloat?
    var cornerRadius: CGFloat
    var showsFooter: Bool
    var showsHeader: Bool
    var isEnabled: Bool
    var badgePalette: DSAudioTranscriptionBadgePalette
    var autoScrollsToBottom: Bool
    var autoScrollUserOverrideDistance: CGFloat

    init(
        minHeight: CGFloat = 96,
        maxHeight: CGFloat? = 240,
        cornerRadius: CGFloat = 10,
        showsFooter: Bool = true,
        showsHeader: Bool = true,
        isEnabled: Bool = true,
        badgePalette: DSAudioTranscriptionBadgePalette = .default,
        autoScrollsToBottom: Bool = true,
        autoScrollUserOverrideDistance: CGFloat = 48
    ) {
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.cornerRadius = cornerRadius
        self.showsFooter = showsFooter
        self.showsHeader = showsHeader
        self.isEnabled = isEnabled
        self.badgePalette = badgePalette
        self.autoScrollsToBottom = autoScrollsToBottom
        self.autoScrollUserOverrideDistance = autoScrollUserOverrideDistance
    }

    static let `default` = DSAudioTranscriptionInputConfig()
}
