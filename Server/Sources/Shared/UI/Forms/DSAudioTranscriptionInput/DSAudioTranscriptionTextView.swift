import AppKit
import SwiftUI

struct DSAudioTranscriptionTextView: NSViewRepresentable {
    @Binding var text: String

    var placeholder: String
    var segments: [DSAudioTranscriptionSegment]
    var isEnabled: Bool
    var badgePalette: DSAudioTranscriptionBadgePalette
    var autoScrollsToBottom: Bool
    var autoScrollUserOverrideDistance: CGFloat
    var shouldAutoScrollToBottom: Bool
    var forceFollowBottom: Bool

    func makeCoordinator() -> DSAudioTranscriptionTextViewCoordinator {
        DSAudioTranscriptionTextViewCoordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = DSAudioTranscriptionTextScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textStorage = NSTextStorage()
        let layoutManager = DSAudioTranscriptionBadgeLayoutManager()
        layoutManager.badgePalette = badgePalette
        let textContainer = NSTextContainer(containerSize: NSSize(
            width: scrollView.contentSize.width,
            height: .greatestFiniteMagnitude
        ))
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesInspectorBar = false
        textView.isEditable = isEnabled
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.textColor = NSColor.labelColor
        textView.typingAttributes = DSAudioTranscriptionTextViewAttributes.baseTypingAttributes()
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        scrollView.documentView = textView

        context.coordinator.textView = textView
        context.coordinator.render(
            text: text,
            segments: segments,
            badgePalette: badgePalette,
            force: true
        )
        scrollView.ensureTextViewFillsVisibleHeight()
        scrollView.scheduleAutoScrollIfNeeded(
            autoScrollsToBottom: autoScrollsToBottom,
            shouldAutoScrollToBottom: shouldAutoScrollToBottom,
            forceFollowBottom: forceFollowBottom,
            distanceFromBottomOverride: autoScrollUserOverrideDistance
        )

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        textView.isEditable = isEnabled
        if let layoutManager = textView.layoutManager as? DSAudioTranscriptionBadgeLayoutManager {
            layoutManager.badgePalette = badgePalette
        }

        context.coordinator.textView = textView
        context.coordinator.render(
            text: text,
            segments: segments,
            badgePalette: badgePalette,
            force: false
        )

        if let scrollView = scrollView as? DSAudioTranscriptionTextScrollView {
            scrollView.ensureTextViewFillsVisibleHeight()
            scrollView.scheduleAutoScrollIfNeeded(
                autoScrollsToBottom: autoScrollsToBottom,
                shouldAutoScrollToBottom: shouldAutoScrollToBottom,
                forceFollowBottom: forceFollowBottom,
                distanceFromBottomOverride: autoScrollUserOverrideDistance
            )
        }
    }
}

final class DSAudioTranscriptionTextScrollView: NSScrollView {
    private(set) var isUserNearBottom: Bool = true
    var autoScrollUserOverrideDistance: CGFloat = 48

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func tile() {
        super.tile()
        ensureTextViewFillsVisibleHeight()
        updateUserNearBottomState()
    }

    override func reflectScrolledClipView(_ cView: NSClipView) {
        super.reflectScrolledClipView(cView)
        updateUserNearBottomState()
    }

    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        updateUserNearBottomState()
    }

    func ensureTextViewFillsVisibleHeight() {
        guard let textView = documentView as? NSTextView else {
            return
        }

        let minimumVisibleHeight = contentView.bounds.height
        let usedHeight = usedTextHeight(for: textView)
        let targetHeight = max(minimumVisibleHeight, usedHeight)

        if abs(textView.frame.height - targetHeight) > 0.5 || abs(textView.frame.width - contentView.bounds.width) > 0.5 {
            textView.frame = NSRect(
                x: 0,
                y: 0,
                width: contentView.bounds.width,
                height: targetHeight
            )
        }
    }

    func updateUserNearBottomState() {
        guard let documentView else {
            isUserNearBottom = true
            return
        }

        let visibleRect = documentVisibleRect
        let distanceFromBottom = max(0, documentView.bounds.maxY - visibleRect.maxY)
        isUserNearBottom = distanceFromBottom <= autoScrollUserOverrideDistance
    }

    func scrollToBottom(animated: Bool = false) {
        _ = animated
        guard let documentView else {
            return
        }

        let bottomY = max(0, documentView.bounds.maxY - contentView.bounds.height)
        contentView.scroll(to: NSPoint(x: 0, y: bottomY))
        reflectScrolledClipView(contentView)
        updateUserNearBottomState()
    }

    func scheduleAutoScrollIfNeeded(
        autoScrollsToBottom: Bool,
        shouldAutoScrollToBottom: Bool,
        forceFollowBottom: Bool,
        distanceFromBottomOverride: CGFloat
    ) {
        guard autoScrollsToBottom else {
            return
        }

        autoScrollUserOverrideDistance = distanceFromBottomOverride
        updateUserNearBottomState()

        guard shouldAutoScrollToBottom else {
            return
        }

        guard forceFollowBottom || isUserNearBottom else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.ensureTextViewFillsVisibleHeight()
            self.scrollToBottom(animated: false)
        }
    }

    override func mouseDown(with event: NSEvent) {
        if let textView = documentView as? NSTextView {
            window?.makeFirstResponder(textView)
        }

        super.mouseDown(with: event)
    }

    private func usedTextHeight(for textView: NSTextView) -> CGFloat {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return contentView.bounds.height
        }

        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        return ceil(usedRect.height + (textView.textContainerInset.height * 2) + 2)
    }
}
