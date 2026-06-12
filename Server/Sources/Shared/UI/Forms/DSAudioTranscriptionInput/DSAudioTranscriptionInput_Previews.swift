import SwiftUI

struct DSAudioTranscriptionInput_Previews: PreviewProvider {
    static var previews: some View {
        DSAudioTranscriptionInputPreviewCatalog()
            .frame(minWidth: 360, idealWidth: 720, maxWidth: .infinity, minHeight: 900)
    }

    @MainActor
    private static func previewSection(
        title: String,
        text: String,
        controller: DSAudioTranscriptionInputPreviewController,
        showsCommitButton: Bool = false,
        manualEditReplacementText: String? = nil,
        manualCommitText: String = "This is the final refined text appended after Whisper."
    ) -> some View {
        DSAudioTranscriptionInputPreviewSection(
            title: title,
            initialText: text,
            controller: controller,
            showsCommitButton: showsCommitButton,
            manualEditReplacementText: manualEditReplacementText,
            manualCommitText: manualCommitText,
            config: .default
        )
    }
}

struct DSAudioTranscriptionInputPreviewCatalog: View {
    @State private var realtimeAccent: DSAudioTranscriptionRealtimeBadgeAccent = .blue

    private var previewConfig: DSAudioTranscriptionInputConfig {
        var config = DSAudioTranscriptionInputConfig.default
        config.badgePalette = DSAudioTranscriptionBadgePalette(
            queued: config.badgePalette.queued,
            processing: config.badgePalette.processing,
            realtime: config.badgePalette.realtime,
            realtimeAccent: realtimeAccent
        )
        return config
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    Text("Realtime badge accent")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Realtime accent", selection: $realtimeAccent) {
                        Text("Blue").tag(DSAudioTranscriptionRealtimeBadgeAccent.blue)
                        Text("Green").tag(DSAudioTranscriptionRealtimeBadgeAccent.green)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                .padding(.bottom, 8)
                previewSection(
                    title: "Idle empty",
                    text: "",
                    controller: DSAudioTranscriptionInputPreviewController(
                        lifecycle: .idle,
                        isListening: false,
                        isSilent: false,
                        isPostProcessing: false,
                        statusText: nil,
                        errorText: nil,
                        inlineSegments: []
                    )
                )

                previewSection(
                    title: "Idle with final text",
                    text: "This is already processed editable text. The user can continue typing here.",
                    controller: DSAudioTranscriptionInputPreviewController(
                        lifecycle: .idle,
                        isListening: false,
                        isSilent: false,
                        isPostProcessing: false,
                        statusText: nil,
                        errorText: nil,
                        inlineSegments: []
                    )
                )

                previewSection(
                    title: "Listening silent",
                    text: "Existing editable text before silence.",
                    controller: DSAudioTranscriptionInputPreviewController(
                        lifecycle: .silent,
                        isListening: true,
                        isSilent: true,
                        isPostProcessing: false,
                        statusText: "Silence detected",
                        errorText: nil,
                        inlineSegments: []
                    )
                )

                previewSection(
                    title: "Apple realtime only",
                    text: "Existing editable text before realtime recognition.",
                    controller: DSAudioTranscriptionInputPreviewController(
                        lifecycle: .recognizing,
                        isListening: true,
                        isSilent: false,
                        isPostProcessing: false,
                        statusText: "Recognizing",
                        errorText: nil,
                        inlineSegments: [
                            DSAudioTranscriptionSegment(
                                kind: .appleRealtime,
                                text: "this is being recognized by Apple Speech in realtime"
                            )
                        ]
                    )
                )

                previewSection(
                    title: "1 processing + 2 queued",
                    text: "Final text before queued follow-up segments.",
                    controller: DSAudioTranscriptionInputPreviewController(
                        lifecycle: .postProcessing,
                        isListening: true,
                        isSilent: true,
                        isPostProcessing: true,
                        statusText: "Post-processing • Queue: 2",
                        errorText: nil,
                        inlineSegments: [
                            DSAudioTranscriptionSegment(
                                kind: .whisperProcessing,
                                text: "first spoken segment currently being refined by Whisper"
                            ),
                            DSAudioTranscriptionSegment(
                                kind: .queued,
                                text: "second queued segment waiting for Whisper"
                            ),
                            DSAudioTranscriptionSegment(
                                kind: .queued,
                                text: "third queued segment waiting for Whisper"
                            )
                        ]
                    )
                )

                previewSection(
                    title: "Whisper processing only",
                    text: "Final text before Whisper processing.",
                    controller: DSAudioTranscriptionInputPreviewController(
                        lifecycle: .postProcessing,
                        isListening: false,
                        isSilent: true,
                        isPostProcessing: true,
                        statusText: "Post-processing",
                        errorText: nil,
                        inlineSegments: [
                            DSAudioTranscriptionSegment(
                                kind: .whisperProcessing,
                                text: "recognized Apple segment currently being refined by Whisper"
                            )
                        ]
                    )
                )

                previewSection(
                    title: "Processing + Apple realtime",
                    text: "Final editable text before simultaneous processing and realtime speech.",
                    controller: DSAudioTranscriptionInputPreviewController(
                        lifecycle: .recognizing,
                        isListening: true,
                        isSilent: false,
                        isPostProcessing: true,
                        statusText: "Post-processing • Recognizing",
                        errorText: nil,
                        inlineSegments: [
                            DSAudioTranscriptionSegment(
                                kind: .whisperProcessing,
                                text: "previous spoken segment currently being refined by Whisper"
                            ),
                            DSAudioTranscriptionSegment(
                                kind: .appleRealtime,
                                text: "new speech being recognized by Apple in realtime"
                            )
                        ]
                    )
                )

                previewSection(
                    title: "Processing + queue + Apple realtime",
                    text: "Edited final text before all temporary inline badge states.",
                    controller: DSAudioTranscriptionInputPreviewController(
                        lifecycle: .recognizing,
                        isListening: true,
                        isSilent: false,
                        isPostProcessing: true,
                        statusText: "Post-processing • Queue: 2 • Recognizing",
                        errorText: nil,
                        inlineSegments: [
                            DSAudioTranscriptionSegment(
                                kind: .whisperProcessing,
                                text: "first spoken segment currently being refined by Whisper"
                            ),
                            DSAudioTranscriptionSegment(
                                kind: .queued,
                                text: "second spoken segment waiting for Whisper"
                            ),
                            DSAudioTranscriptionSegment(
                                kind: .queued,
                                text: "third spoken segment waiting for Whisper"
                            ),
                            DSAudioTranscriptionSegment(
                                kind: .appleRealtime,
                                text: "current speech being recognized by Apple realtime"
                            )
                        ]
                    ),
                    showsCommitButton: true
                )

                previewSection(
                    title: "Full mixed state: 1 processing + 3 queued + 1 realtime",
                    text: "User already typed this text and continues speaking while Whisper is still working.",
                    controller: DSAudioTranscriptionInputPreviewController(
                        lifecycle: .recognizing,
                        isListening: true,
                        isSilent: false,
                        isPostProcessing: true,
                        statusText: "Post-processing • Queue: 3 • Recognizing",
                        errorText: nil,
                        inlineSegments: [
                            DSAudioTranscriptionSegment(
                                kind: .whisperProcessing,
                                text: "oldest spoken segment currently being refined by Whisper"
                            ),
                            DSAudioTranscriptionSegment(
                                kind: .queued,
                                text: "queued segment one waiting for Whisper"
                            ),
                            DSAudioTranscriptionSegment(
                                kind: .queued,
                                text: "queued segment two waiting for Whisper"
                            ),
                            DSAudioTranscriptionSegment(
                                kind: .queued,
                                text: "queued segment three waiting for Whisper"
                            ),
                            DSAudioTranscriptionSegment(
                                kind: .appleRealtime,
                                text: "newest realtime Apple recognition text still being spoken"
                            )
                        ]
                    )
                )

                previewSection(
                    title: "Long wrapping combined state",
                    text: "This preview validates inline badge wrapping when the component width changes.",
                    controller: DSAudioTranscriptionInputPreviewController(
                        lifecycle: .recognizing,
                        isListening: true,
                        isSilent: false,
                        isPostProcessing: true,
                        statusText: "Post-processing • Queue: 1 • Recognizing",
                        errorText: nil,
                        inlineSegments: [
                            DSAudioTranscriptionSegment(
                                kind: .whisperProcessing,
                                text: "this is a long processing segment that should stay inline and wrap naturally instead of becoming a separate block"
                            ),
                            DSAudioTranscriptionSegment(
                                kind: .queued,
                                text: "this is a long queued segment waiting for Whisper and it should also wrap naturally inside the text flow"
                            ),
                            DSAudioTranscriptionSegment(
                                kind: .appleRealtime,
                                text: "this is a long realtime Apple recognition partial that must remain at the end and wrap correctly"
                            )
                        ]
                    )
                )

                previewSection(
                    title: "Manual edit preserved before commit",
                    text: "User edited beginning.",
                    controller: DSAudioTranscriptionInputPreviewController(
                        lifecycle: .postProcessing,
                        isListening: false,
                        isSilent: false,
                        isPostProcessing: true,
                        statusText: "Post-processing",
                        errorText: nil,
                        inlineSegments: [
                            DSAudioTranscriptionSegment(
                                kind: .whisperProcessing,
                                text: "voice segment being refined"
                            )
                        ]
                    ),
                    showsCommitButton: true,
                    manualEditReplacementText: "User corrected the beginning manually.",
                    manualCommitText: "voice segment finished"
                )

                previewSection(
                    title: "Error",
                    text: "Text remains editable even when an error is visible.",
                    controller: DSAudioTranscriptionInputPreviewController(
                        lifecycle: .error,
                        isListening: false,
                        isSilent: false,
                        isPostProcessing: false,
                        statusText: nil,
                        errorText: "Microphone permission denied.",
                        inlineSegments: []
                    )
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minWidth: 360, idealWidth: 720, maxWidth: .infinity, minHeight: 900)
    }

    @MainActor
    private func previewSection(
        title: String,
        text: String,
        controller: DSAudioTranscriptionInputPreviewController,
        showsCommitButton: Bool = false,
        manualEditReplacementText: String? = nil,
        manualCommitText: String = "This is the final refined text appended after Whisper."
    ) -> some View {
        DSAudioTranscriptionInputPreviewSection(
            title: title,
            initialText: text,
            controller: controller,
            showsCommitButton: showsCommitButton,
            manualEditReplacementText: manualEditReplacementText,
            manualCommitText: manualCommitText,
            config: previewConfig
        )
    }
}

struct DSAudioTranscriptionInput_Previews_PreviewContent: View {
    var body: some View {
        DSAudioTranscriptionInputPreviewCatalog()
    }
}

private struct DSAudioTranscriptionInputPreviewSection: View {
    let title: String
    let showsCommitButton: Bool
    let manualEditReplacementText: String?
    let manualCommitText: String
    let config: DSAudioTranscriptionInputConfig
    @State var text: String
    @StateObject var controller: DSAudioTranscriptionInputPreviewController

    init(
        title: String,
        initialText: String,
        controller: DSAudioTranscriptionInputPreviewController,
        showsCommitButton: Bool = false,
        manualEditReplacementText: String? = nil,
        manualCommitText: String = "This is the final refined text appended after Whisper.",
        config: DSAudioTranscriptionInputConfig
    ) {
        self.title = title
        self.showsCommitButton = showsCommitButton
        self.manualEditReplacementText = manualEditReplacementText
        self.manualCommitText = manualCommitText
        self.config = config
        self._text = State(initialValue: initialText)
        self._controller = StateObject(wrappedValue: controller)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            DSAudioTranscriptionInput(
                title: "Message",
                placeholder: "Type or speak...",
                mode: .textarea,
                text: $text,
                controller: controller,
                config: config
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsCommitButton {
                HStack(spacing: 8) {
                    if let manualEditReplacementText {
                        Button("Simulate manual text edit") {
                            text = manualEditReplacementText
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Button("Preview commit processed text") {
                        controller.previewCommitText(manualCommitText)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
