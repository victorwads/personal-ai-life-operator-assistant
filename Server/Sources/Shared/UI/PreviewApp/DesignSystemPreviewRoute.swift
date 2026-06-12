import SwiftUI

enum DesignSystemPreviewRoute: String, CaseIterable, Identifiable, Hashable {
    case buttons
    case badges
    case runtimeStatus
    case headers
    case flowLayout
    case cards
    case containers
    case titledSections
    case listRows
    case codeBlocks
    case debugInspectors
    case messageBubbles
    case formFields
    case audioTranscriptionInput
    case audioTranscriptionInputLive

    enum Category: String, CaseIterable, Identifiable {
        case foundations
        case layout
        case dataDisplay
        case messaging
        case forms

        var id: String { rawValue }

        var title: String {
            switch self {
            case .foundations:
                return "Foundations"
            case .layout:
                return "Layout"
            case .dataDisplay:
                return "Data Display"
            case .messaging:
                return "Messaging"
            case .forms:
                return "Forms"
            }
        }
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buttons:
            return "Buttons"
        case .badges:
            return "Badges"
        case .runtimeStatus:
            return "Runtime Status"
        case .headers:
            return "Headers"
        case .flowLayout:
            return "Flow Layout"
        case .cards:
            return "Cards"
        case .containers:
            return "Containers"
        case .titledSections:
            return "Titled Sections"
        case .listRows:
            return "List Rows"
        case .codeBlocks:
            return "Code Blocks"
        case .debugInspectors:
            return "Debug Inspectors"
        case .messageBubbles:
            return "Message Bubbles"
        case .formFields:
            return "Text Fields"
        case .audioTranscriptionInput:
            return "Audio Transcription Input"
        case .audioTranscriptionInputLive:
            return "Audio Transcription Live"
        }
    }

    var category: Category {
        switch self {
        case .buttons, .badges, .runtimeStatus:
            return .foundations
        case .headers, .flowLayout, .cards, .containers, .titledSections:
            return .layout
        case .listRows, .codeBlocks, .debugInspectors:
            return .dataDisplay
        case .messageBubbles:
            return .messaging
        case .formFields, .audioTranscriptionInput, .audioTranscriptionInputLive:
            return .forms
        }
    }

    var systemImage: String {
        switch self {
        case .buttons:
            return "rectangle.3.group"
        case .badges:
            return "tag"
        case .runtimeStatus:
            return "dot.radiowaves.left.and.right"
        case .headers:
            return "rectangle.topthird.inset.filled"
        case .flowLayout:
            return "square.grid.2x2"
        case .cards:
            return "square.on.square"
        case .containers:
            return "square.stack.3d.up"
        case .titledSections:
            return "text.alignleft"
        case .listRows:
            return "list.bullet.rectangle"
        case .codeBlocks:
            return "chevron.left.forwardslash.chevron.right"
        case .debugInspectors:
            return "curlybraces.square"
        case .messageBubbles:
            return "message"
        case .formFields:
            return "textbox"
        case .audioTranscriptionInput:
            return "mic"
        case .audioTranscriptionInputLive:
            return "mic.fill"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .buttons:
            ButtonsPreviewPage()
        case .badges:
            BadgesPreviewPage()
        case .runtimeStatus:
            RuntimeStatusPreviewPage()
        case .headers:
            HeadersPreviewPage()
        case .flowLayout:
            FlowLayoutPreviewPage()
        case .cards:
            CardsPreviewPage()
        case .containers:
            ContainersPreviewPage()
        case .titledSections:
            TitledSectionsPreviewPage()
        case .listRows:
            ListRowsPreviewPage()
        case .codeBlocks:
            CodeBlocksPreviewPage()
        case .debugInspectors:
            DebugInspectorsPreviewPage()
        case .messageBubbles:
            MessageBubblesPreviewPage()
        case .formFields:
            FormFieldsPreviewPage()
        case .audioTranscriptionInput:
            AudioTranscriptionInputPreviewPage()
        case .audioTranscriptionInputLive:
            DSAudioTranscriptionInputLiveVoicePreview()
        }
    }

    static func routes(in category: Category) -> [DesignSystemPreviewRoute] {
        allCases.filter { $0.category == category }
    }
}
