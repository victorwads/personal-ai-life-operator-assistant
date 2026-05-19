import Foundation

extension AppModel {
    func shutdown() async {
        pollingTask?.cancel()
        pollingTask = nil
        permissionMonitorTask?.cancel()
        permissionMonitorTask = nil
        liveStatusTask?.cancel()
        liveStatusTask = nil

        if mcpServerRunning {
            await stopMCPServer()
        }

        isPolling = false
    }
}
