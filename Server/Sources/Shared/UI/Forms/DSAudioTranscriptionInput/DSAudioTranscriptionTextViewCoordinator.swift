import AppKit
import SwiftUI

final class DSAudioTranscriptionTextViewCoordinator: NSObject, NSTextViewDelegate {
    @Binding private var text: String

    weak var textView: NSTextView?

    private var isRendering = false
    private var lastRenderedText = ""
    private var lastRenderedSegments: [DSAudioTranscriptionSegment] = []
    private var lastRenderedBadgePalette: DSAudioTranscriptionBadgePalette = .default

    init(text: Binding<String>) {
        self._text = text
    }

    func render(
        text: String,
        segments: [DSAudioTranscriptionSegment],
        badgePalette: DSAudioTranscriptionBadgePalette,
        force: Bool
    ) {
        guard let textView else {
            return
        }

        let orderedSegments = orderedSegments(segments)
        let shouldRender =
            force ||
            text != lastRenderedText ||
            orderedSegments != lastRenderedSegments ||
            badgePalette != lastRenderedBadgePalette

        guard shouldRender else {
            return
        }

        isRendering = true
        defer { isRendering = false }

        let selectedRanges = textView.selectedRanges
        let attributed = makeAttributedString(
            text: text,
            segments: orderedSegments,
            badgePalette: badgePalette
        )

        textView.textStorage?.setAttributedString(attributed)
        textView.typingAttributes = DSAudioTranscriptionTextViewAttributes.baseTypingAttributes()
        restoreSelection(selectedRanges, in: textView)
        textView.toolTip = makeGeneralTooltip(for: orderedSegments)

        lastRenderedText = text
        lastRenderedSegments = orderedSegments
        lastRenderedBadgePalette = badgePalette
    }

    func textDidChange(_ notification: Notification) {
        guard !isRendering else {
            return
        }

        guard let textView = notification.object as? NSTextView else {
            return
        }

        let editableText = extractEditableText(from: textView.attributedString())
        if text != editableText {
            text = editableText
        }

        lastRenderedText = editableText
    }

    func textView(
        _ textView: NSTextView,
        shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        guard let storage = textView.textStorage else {
            return true
        }

        if storage.length == 0 {
            return true
        }

        if affectedCharRange.length == 0 {
            return canInsert(at: affectedCharRange.location, in: storage)
        }

        var touchesLockedSegment = false
        storage.enumerateAttribute(
            .dsAudioLockedSegmentID,
            in: affectedCharRange,
            options: []
        ) { value, _, stop in
            if value != nil {
                touchesLockedSegment = true
                stop.pointee = true
            }
        }

        return !touchesLockedSegment
    }

    private func canInsert(at location: Int, in storage: NSTextStorage) -> Bool {
        if location < storage.length,
           storage.attribute(.dsAudioLockedSegmentID, at: location, effectiveRange: nil) != nil {
            return false
        }

        if location > 0,
           storage.attribute(.dsAudioLockedSegmentID, at: location - 1, effectiveRange: nil) != nil {
            return false
        }

        return true
    }

    private func orderedSegments(_ segments: [DSAudioTranscriptionSegment]) -> [DSAudioTranscriptionSegment] {
        let processing = segments.filter { $0.kind == .whisperProcessing }
        let queued = segments.filter { $0.kind == .queued }
        let realtime = segments.filter { $0.kind == .appleRealtime }
        return processing + queued + realtime
    }

    private func makeAttributedString(
        text: String,
        segments: [DSAudioTranscriptionSegment],
        badgePalette: DSAudioTranscriptionBadgePalette
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let editableAttributes = DSAudioTranscriptionTextViewAttributes.baseTypingAttributes()

        result.append(NSAttributedString(string: text, attributes: editableAttributes))

        for segment in segments {
            let trimmedSegmentText = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedSegmentText.isEmpty else { continue }

            if result.length > 0 {
                result.append(NSAttributedString(
                    string: "   ",
                    attributes: editableAttributes)
                )
            }

            let badgeText = "\u{00A0}\(trimmedSegmentText)\u{00A0}\u{00A0}"
            let badgeAttributes = DSAudioTranscriptionTextViewAttributes.badgeAttributes(
                for: segment.kind,
                segmentID: segment.id,
                badgePalette: badgePalette
            )
            let badgeStart = result.length

            result.append(NSAttributedString(string: badgeText, attributes: badgeAttributes))
            result.append(
                iconAttributedString(
                    for: segment.kind,
                    segmentID: segment.id,
                    badgePalette: badgePalette
                )
            )
            result.append(NSAttributedString(string: "\u{00A0}", attributes: badgeAttributes))

            let badgeRange = NSRange(location: badgeStart, length: result.length - badgeStart)
            result.addAttributes(badgeAttributes, range: badgeRange)
        }

        return result
    }

    private func iconAttributedString(
        for kind: DSAudioTranscriptionSegmentKind,
        segmentID: UUID,
        badgePalette: DSAudioTranscriptionBadgePalette
    ) -> NSAttributedString {
        let iconAttributes = DSAudioTranscriptionTextViewAttributes.badgeAttributes(
            for: kind,
            segmentID: segmentID,
            badgePalette: badgePalette
        )

        switch kind.icon {
        case .text(let value):
            return NSAttributedString(
                string: value,
                attributes: iconAttributes
            )

        case .systemSymbol(let symbolName):
            return systemSymbolAttributedString(
                symbolName: symbolName,
                kind: kind,
                segmentID: segmentID,
                badgePalette: badgePalette
            )
        }
    }

    private func systemSymbolAttributedString(
        symbolName: String,
        kind: DSAudioTranscriptionSegmentKind,
        segmentID: UUID,
        badgePalette: DSAudioTranscriptionBadgePalette
    ) -> NSAttributedString {
        let foregroundColor = DSAudioTranscriptionTextViewAttributes.badgeForegroundColor(
            for: kind,
            badgePalette: badgePalette
        )

        let attachment = NSTextAttachment()
        attachment.image = symbolImage(
            systemName: symbolName,
            tintColor: foregroundColor
        )
        attachment.bounds = NSRect(x: 0, y: -1, width: 10, height: 10)

        let attributes = DSAudioTranscriptionTextViewAttributes.badgeAttributes(
            for: kind,
            segmentID: segmentID,
            badgePalette: badgePalette
        )

        let result = NSMutableAttributedString(
            attributedString: NSAttributedString(attachment: attachment)
        )

        result.addAttributes(
            attributes,
            range: NSRange(location: 0, length: result.length)
        )

        return result
    }

    private func symbolImage(
        systemName: String,
        tintColor: NSColor
    ) -> NSImage? {
        let baseConfiguration = NSImage.SymbolConfiguration(
            pointSize: 10,
            weight: .semibold
        )

        let colorConfiguration = NSImage.SymbolConfiguration(
            hierarchicalColor: tintColor
        )

        let configuration = baseConfiguration.applying(colorConfiguration)

        let image = NSImage(
            systemSymbolName: systemName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(configuration)

        image?.isTemplate = false
        return image
    }

    private func extractEditableText(from attributedString: NSAttributedString) -> String {
        let result = NSMutableString()

        attributedString.enumerateAttribute(
            .dsAudioEditableText,
            in: NSRange(location: 0, length: attributedString.length),
            options: []
        ) { value, range, _ in
            guard let isEditable = value as? Bool, isEditable else {
                return
            }

            result.append(attributedString.attributedSubstring(from: range).string)
        }

        return result as String
    }

    private func restoreSelection(_ selectedRanges: [NSValue], in textView: NSTextView) {
        guard let firstRange = selectedRanges.first?.rangeValue else {
            return
        }

        let stringLength = (textView.string as NSString).length
        let safeLocation = min(firstRange.location, stringLength)
        let safeLength = min(firstRange.length, max(0, stringLength - safeLocation))

        textView.setSelectedRange(NSRange(location: safeLocation, length: safeLength))
    }

    private func makeGeneralTooltip(for segments: [DSAudioTranscriptionSegment]) -> String? {
        guard !segments.isEmpty else {
            return nil
        }

        let uniqueHelpTexts = Array(Set(segments.map(\.kind.helpText))).sorted()
        return uniqueHelpTexts.joined(separator: "\n")
    }
}
