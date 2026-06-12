import AppKit

final class DSAudioTranscriptionBadgeLayoutManager: NSLayoutManager {
    var badgePalette: DSAudioTranscriptionBadgePalette = .default

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)

        guard let textStorage else {
            return
        }

        let characterRange = characterRange(
            forGlyphRange: glyphsToShow,
            actualGlyphRange: nil
        )

        textStorage.enumerateAttribute(
            .dsAudioLockedSegmentID,
            in: characterRange,
            options: []
        ) { value, segmentCharacterRange, _ in
            guard value != nil else {
                return
            }

            let segmentGlyphRange = self.glyphRange(
                forCharacterRange: segmentCharacterRange,
                actualCharacterRange: nil
            )
            let visibleGlyphRange = NSIntersectionRange(segmentGlyphRange, glyphsToShow)

            guard visibleGlyphRange.length > 0 else {
                return
            }

            let kind = self.segmentKind(
                in: textStorage,
                characterRange: segmentCharacterRange
            )
            drawBadgeBackground(
                for: visibleGlyphRange,
                fullSegmentGlyphRange: segmentGlyphRange,
                kind: kind,
                origin: origin
            )
        }
    }

    private func drawBadgeBackground(
        for glyphRange: NSRange,
        fullSegmentGlyphRange: NSRange,
        kind: DSAudioTranscriptionSegmentKind,
        origin: NSPoint
    ) {
        enumerateLineFragments(forGlyphRange: glyphRange) { lineFragmentRect, usedRect, textContainer, lineGlyphRange, _ in
            let fragmentGlyphRange = NSIntersectionRange(fullSegmentGlyphRange, lineGlyphRange)

            let lineRect = lineFragmentRect.offsetBy(dx: origin.x, dy: origin.y-1)
            let containerRect = lineRect

            var glyphRect = self.boundingRect(
                forGlyphRange: fragmentGlyphRange,
                in: textContainer
            )

            guard !glyphRect.isEmpty else {
                return
            }

            glyphRect.origin.x += origin.x
            glyphRect.origin.y += origin.y

            let badgeHeight: CGFloat = 20
            let badgeYOffset: CGFloat = 3
            let badgeHorizontalPadding: CGFloat = 4

            let minX = max(containerRect.minX, glyphRect.minX - badgeHorizontalPadding)
            let maxX = min(containerRect.maxX, glyphRect.maxX + badgeHorizontalPadding)

            let badgeY = lineRect.minY + ((lineRect.height - badgeHeight) / 2) + badgeYOffset

            let badgeRect = NSRect(
                x: minX,
                y: badgeY,
                width: max(0, maxX - minX),
                height: badgeHeight
            )

            guard badgeRect.width > 0, badgeRect.height > 0 else {
                return
            }

            let fillColor = self.badgeFillColor(for: kind)
            fillColor.setFill()

            let path = NSBezierPath(
                roundedRect: badgeRect,
                xRadius: 7,
                yRadius: 7
            )
            path.fill()
        }
    }

    private func segmentKind(
        in textStorage: NSTextStorage,
        characterRange: NSRange
    ) -> DSAudioTranscriptionSegmentKind {
        guard characterRange.location < textStorage.length,
              let rawValue = textStorage.attribute(
                  .dsAudioLockedSegmentKind,
                  at: characterRange.location,
                  effectiveRange: nil
              ) as? String,
              let kind = DSAudioTranscriptionSegmentKind(rawValue: rawValue) else {
            return .queued
        }

        return kind
    }

    private func badgeFillColor(for kind: DSAudioTranscriptionSegmentKind) -> NSColor {
        switch kind {
        case .queued:
            return DSAudioTranscriptionTextViewAttributes.badgeFillColor(
                for: kind,
                badgePalette: badgePalette
            )
        case .whisperProcessing:
            return DSAudioTranscriptionTextViewAttributes.badgeFillColor(
                for: kind,
                badgePalette: badgePalette
            )
        case .appleRealtime:
            return DSAudioTranscriptionTextViewAttributes.badgeFillColor(
                for: kind,
                badgePalette: badgePalette
            )
        }
    }
}
