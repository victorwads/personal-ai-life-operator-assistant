import Foundation

@MainActor
protocol ProfileWindowManaging: AnyObject {
    func showProfileWindow(profile: Profile)
    func hideProfileWindow(profileId: String)
    func isProfileWindowVisible(profileId: String) -> Bool
}
