import Foundation

enum RuntimeEnvironment {
    static var isXcodePreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    static var isTestingRuntime: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
    
    static var isStandardAppRuntime: Bool {
        !isXcodePreview && !isTestingRuntime
    }
}
