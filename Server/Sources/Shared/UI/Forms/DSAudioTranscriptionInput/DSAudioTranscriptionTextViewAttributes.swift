import AppKit

extension NSAttributedString.Key {
    static let dsAudioEditableText = NSAttributedString.Key("dsAudioEditableText")
    static let dsAudioLockedSegmentID = NSAttributedString.Key("dsAudioLockedSegmentID")
    static let dsAudioLockedSegmentKind = NSAttributedString.Key("dsAudioLockedSegmentKind")
}

enum DSAudioTranscriptionTextViewAttributes {
    private static let badgeFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)

    static func baseTypingAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: badgeFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle(),
            .dsAudioEditableText: true
        ]
    }

    static func badgeAttributes(
        for kind: DSAudioTranscriptionSegmentKind,
        segmentID: UUID,
        badgePalette: DSAudioTranscriptionBadgePalette
    ) -> [NSAttributedString.Key: Any] {
        let foregroundColor = badgeForegroundColor(
            for: kind,
            badgePalette: badgePalette
        )

        return [
            .font: badgeFont,
            .foregroundColor: foregroundColor,
            .paragraphStyle: paragraphStyle(),
            .dsAudioLockedSegmentID: segmentID.uuidString,
            .dsAudioLockedSegmentKind: kind.rawValue
        ]
    }

    static func badgeForegroundColor(
        for kind: DSAudioTranscriptionSegmentKind,
        badgePalette: DSAudioTranscriptionBadgePalette
    ) -> NSColor {
        switch surface(for: kind, badgePalette: badgePalette) {
        case .realtimeUnstable:
            switch badgePalette.realtimeAccent {
            case .blue:
                return realtimeBlueForegroundColor()
            case .green:
                return realtimeGreenForegroundColor()
            }

        case .queuedMuted:
            return dynamicColor(
                dark: NSColor(calibratedWhite: 0.68, alpha: 0.8),
                light: NSColor(calibratedWhite: 0.34, alpha: 0.8)
            )

        case .processingStrong:
            return dynamicColor(
                dark: NSColor(calibratedWhite: 0.96, alpha: 0.7),
                light: NSColor(calibratedWhite: 0.22, alpha: 0.7)
            )
        }
    }

    static func badgeFillColor(
        for kind: DSAudioTranscriptionSegmentKind,
        badgePalette: DSAudioTranscriptionBadgePalette
    ) -> NSColor {
        switch surface(for: kind, badgePalette: badgePalette) {
        case .realtimeUnstable:
            switch badgePalette.realtimeAccent {
            case .blue:
                return realtimeBlueFillColor()
            case .green:
                return realtimeGreenFillColor()
            }

        case .queuedMuted:
            return dynamicColor(
                dark: NSColor(calibratedWhite: 0.32, alpha: 0.8),
                light: NSColor(calibratedWhite: 0.78, alpha: 0.8)
            )

        case .processingStrong:
            return dynamicColor(
                dark: NSColor(calibratedWhite: 0.17, alpha: 0.7),
                light: NSColor(calibratedWhite: 0.88, alpha: 0.5)
            )
        }
    }

    private static func realtimeBlueFillColor() -> NSColor {
        dynamicColor(
            dark: NSColor(calibratedRed: 0.12, green: 0.22, blue: 0.30, alpha: 1.0),
            light: NSColor(calibratedRed: 0.82, green: 0.94, blue: 0.98, alpha: 1.0)
        )
    }

    private static func realtimeBlueForegroundColor() -> NSColor {
        dynamicColor(
            dark: NSColor(calibratedRed: 0.62, green: 0.78, blue: 0.90, alpha: 1.0),
            light: NSColor(calibratedRed: 0.10, green: 0.34, blue: 0.46, alpha: 1.0)
        )
    }

    private static func realtimeGreenFillColor() -> NSColor {
        dynamicColor(
            dark: NSColor(calibratedRed: 0.10, green: 0.26, blue: 0.17, alpha: 1.0),
            light: NSColor(calibratedRed: 0.84, green: 0.96, blue: 0.88, alpha: 1.0)
        )
    }

    private static func realtimeGreenForegroundColor() -> NSColor {
        dynamicColor(
            dark: NSColor(calibratedRed: 0.62, green: 0.84, blue: 0.68, alpha: 1.0),
            light: NSColor(calibratedRed: 0.12, green: 0.42, blue: 0.22, alpha: 1.0)
        )
    }

    private static func dynamicColor(
        dark: NSColor,
        light: NSColor
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? dark : light
        }
    }

    private static func paragraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.minimumLineHeight = 20
        style.maximumLineHeight = 20
        style.lineSpacing = 4
        return style
    }

    private static func surface(
        for kind: DSAudioTranscriptionSegmentKind,
        badgePalette: DSAudioTranscriptionBadgePalette
    ) -> DSAudioTranscriptionBadgeSurface {
        switch kind {
        case .queued:
            return badgePalette.queued
        case .whisperProcessing:
            return badgePalette.processing
        case .appleRealtime:
            return badgePalette.realtime
        }
    }
}
