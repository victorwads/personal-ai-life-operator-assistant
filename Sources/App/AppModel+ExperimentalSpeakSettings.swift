import Combine
import Foundation

extension AppModel {
    func loadExperimentalSpeakSetting() {
        experimentalSpeakApiEnabled = experimentalSpeakSettingsRepository.load(defaultValue: true)
        let enabled = experimentalSpeakApiEnabled
        Task { [weak self] in
            guard let self else { return }
            await voiceAssistant.setExperimentalSpeakEnabled(enabled)
        }
        bindExperimentalSpeakSettingPersistence()
    }

    private func bindExperimentalSpeakSettingPersistence() {
        $experimentalSpeakApiEnabled
            .dropFirst()
            .sink { [weak self] value in
                guard let self else { return }
                experimentalSpeakSettingsRepository.save(value)
                Task { [weak self] in
                    await self?.voiceAssistant.setExperimentalSpeakEnabled(value)
                }
            }
            .store(in: &cancellables)
    }
}
