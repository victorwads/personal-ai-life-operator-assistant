import Foundation

struct AccessibilityRuntime {
    let applicationProvider: AXApplicationProvider
    let elementFinder: AXElementFinder
    let elementExtractor: AXElementExtractor
    let actionExecutor: AXActionExecutor
}
