struct SwiftAPISpeakConfig: SpeakConfig {
    let method: SpeakMethod = .swiftAPI
    var voice: String?
    var language: String?
    var rate: Float?

    init(
        voice: String? = nil,
        language: String? = nil,
        rate: Float? = nil
    ) {
        self.voice = voice
        self.language = language
        self.rate = rate
    }
}
