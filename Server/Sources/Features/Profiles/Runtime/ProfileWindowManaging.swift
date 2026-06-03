import Foundation
import SwiftUI

@MainActor
protocol ProfileWindowManaging: AnyObject {
    func showProfileWindow(profile: Profile)
    func showFeatureWindow(profileId: String, request: FeatureWindowRequest)
    func hideProfileWindow(profileId: String)
    func isProfileWindowVisible(profileId: String) -> Bool
}
