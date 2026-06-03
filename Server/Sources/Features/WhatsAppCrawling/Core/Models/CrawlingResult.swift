import Foundation

enum CrawlingResult<Value> {
    case success(Value)
    case failure(CrawlingError)

    var value: Value? {
        if case let .success(value) = self {
            return value
        }
        return nil
    }

    var error: CrawlingError? {
        if case let .failure(error) = self {
            return error
        }
        return nil
    }

    func map<NewValue>(_ transform: (Value) -> NewValue) -> CrawlingResult<NewValue> {
        switch self {
        case let .success(value):
            return .success(transform(value))
        case let .failure(error):
            return .failure(error)
        }
    }
}
