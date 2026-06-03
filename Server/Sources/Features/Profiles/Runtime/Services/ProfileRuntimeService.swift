import Foundation

@MainActor
protocol ProfileRuntimeService: AnyObject {
    var id: String { get }
    var title: String { get }
    var state: ProfileRuntimeServiceState { get }

    func start() async
    func stop() async
}
