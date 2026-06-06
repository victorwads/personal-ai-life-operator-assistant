import Foundation

@MainActor
final class MCPToolExecutorBridge: AIConnectionToolExecuting {
    private let featureProvider: @MainActor () -> MCPServersFeature

    init(featureProvider: @escaping @MainActor () -> MCPServersFeature) {
        self.featureProvider = featureProvider
    }

    func executeToolCall(_ toolCall: AIRequestedToolCall) async -> AIToolExecutionResult {
        do {
            let mcpArguments = try AIJSONValue.parseObject(from: toolCall.argumentsJSON).mapValues(Self.mcpValue)
            let result = await featureProvider().executeToolCall(
                MCPToolCall(name: toolCall.name, arguments: mcpArguments)
            )
            return Self.aiResult(from: result)
        } catch {
            return AIToolExecutionResult(
                toolName: toolCall.name,
                success: false,
                payload: nil,
                errorMessage: error.localizedDescription,
                suggestedAction: "Return a valid JSON object for tool call arguments.",
                validationErrors: [],
                durationMilliseconds: nil
            )
        }
    }

    private static func aiResult(from result: MCPToolExecutionResult) -> AIToolExecutionResult {
        AIToolExecutionResult(
            toolName: result.toolName,
            success: result.success,
            payload: result.payload.map(aiValue),
            errorMessage: result.error?.localizedDescription,
            suggestedAction: suggestedAction(from: result.error),
            validationErrors: validationErrors(from: result.error),
            durationMilliseconds: result.durationMilliseconds
        )
    }

    private static func suggestedAction(from error: MCPServerError?) -> String? {
        guard let error else {
            return nil
        }

        if case let .validationFailed(validationErrors) = error {
            return validationErrors.map(\.suggestedAction).joined(separator: "\n")
        }

        return nil
    }

    private static func validationErrors(from error: MCPServerError?) -> [AIToolExecutionResult.ValidationError] {
        guard case let .validationFailed(validationErrors)? = error else {
            return []
        }

        return validationErrors.map {
            AIToolExecutionResult.ValidationError(
                fieldPath: $0.fieldPath,
                message: $0.message,
                suggestedAction: $0.suggestedAction
            )
        }
    }

    private static func aiValue(_ value: MCPJSONValue) -> AIJSONValue {
        switch value {
        case .null:
            return .null
        case let .bool(value):
            return .bool(value)
        case let .int(value):
            return .int(value)
        case let .double(value):
            return .double(value)
        case let .string(value):
            return .string(value)
        case let .array(values):
            return .array(values.map(aiValue))
        case let .object(values):
            return .object(values.mapValues(aiValue))
        }
    }

    private static func mcpValue(_ value: AIJSONValue) -> MCPJSONValue {
        switch value {
        case .null:
            return .null
        case let .bool(value):
            return .bool(value)
        case let .int(value):
            return .int(value)
        case let .double(value):
            return .double(value)
        case let .string(value):
            return .string(value)
        case let .array(values):
            return .array(values.map(mcpValue))
        case let .object(values):
            return .object(values.mapValues(mcpValue))
        }
    }
}
