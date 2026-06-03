struct SayCommandSpeakConfig: SpeakConfig {
    let method: SpeakMethod = .command
    var rate: Float?

    init(rate: Float? = nil) {
        self.rate = rate
    }
}
