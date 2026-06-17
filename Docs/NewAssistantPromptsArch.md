# CONCEITUAL AI Runtime KV-Cache Optmizer

eu acho q pré calculado em disco , jogado na memoria ao iniciar o modelo, devem existir:
```swift
let baseSystemImageExtractionKvCache = KVCache(from: disk) ?? createPrefill(ImageExtractionSystemPrompt)
let baseSystemPlusToolsIssueResolverKvCache:  = KVCache(from: disk) ?? createPrefill(ImageExtractionSystemPrompt)
let baseSystemPlusToolsAssistantKvCache:  = KVCache(from: disk) ?? createPrefill(ImageExtractionSystemPrompt)
```

## ao iniciar um image extraction
```swift
let messages = createMessagesFromImage(image)
let currentSessionExtract = baseSystemImageExtractionKvCache.copy()
let result = generate(..., cache=currentSessionExtract, messages)
//...aqui vai ter varias messages chegando e tals... até decidir quais eventos vão para cada issue.

free(currentSessionExtract)
// lidar com result - no need to stream
```

## ao iniciar um Issue Resolver
```swift
let messages = createMessagesFromEvents(events)
let currentSessionResolver = baseSystemPlusToolsIssueResolverKvCache.copy()
let result = generate(..., cache=currentSessionResolver)
stream {
    // execução de tools to add events(user/event messages) to issue, e a ia vai associar messages, ou clientRequestsIteraction aos issues na base etc..
    // ela pode rotear eventos para mais de uma issue ou criar novas, etc.
}
free(currentSessionResolver)

appendIssueMessagesWithEvent()
resolveEvent() // markMessagesAsHandled, markClientIterractionsAsHandled, etc..
```

## ao iniciar um issue Assistant
```swift
let messages = [... from firebase ou from new event, etc..]
let restoredAssitantSessionREsolver = KVCache(issueId, messagesHash, from: disk)
let currentSessionResolver = restoredCurrentSessionREsolver ?? baseSystemPlusToolsIssueResolverKvCache.copy()
let result = generate(..., cache=currentSessionResolver)
stream {
    //...aqui vai ter varias messages chegando e tals... até chamar 1 tool de wait.
    saveFirebaseMessagesHistory(messageOrTollEtc...)
    if (calledToolWait) {
        saveDisk(issueId, messagesHash, currentSessionResolver)
        break // stop generation until new event, maybe wait_for_event should need params for reason/what it is waiting to help Issue Resolver to router the expected events to here.
    } else if (calledResolveSubject) {
        // Here the tool already finhesd this on database, so this context will not return
        removeKVCacheFromDisk()
        break
    }
}

free(currentSessionResolver)
```

## AI Connection
Em geral, o IA Connection que gere as IA deve no código:

runIssueResolver();

let issues = getAssistantReadyIssues();
for each issue in issues {
    runAssistant(issue);
}

Dessa forma, todo cycle ele olha as coisas que mudaram, eventos que chegaram e trabalha 1 a 1 nos assuntos

### runIssueResolver();

Aqui ele atualiza os status das issues para waitingAgent que pode ser algo:
```swift
enum IssueStatus: String, Codable, Equatable, Sendable, CaseIterable { // CONCEITUAL.... Não final
    ...
    case waitingAgent // set only by the IssueResolver agent
    ...
}
```

### getAssistantReadyIssues();

Aqui ele lista do firebase algo como issues.where(status = waitingAgent or runningSession); // runningSession first (to resume if lost by crash or closed app)
Ai inicar a session muda status para:
```swift
enum IssueStatus: String, Codable, Equatable, Sendable, CaseIterable { // CONCEITUAL.... Não final
    ...
    case runningSession // set only by the Assistant agent
    ...
}
```

conforme as tools e decisões forem sendo tomadas e pode mudar para:
```swift
enum IssueStatus: String, Codable, Equatable, Sendable, CaseIterable { // CONCEITUAL.... Não final
    ...
    case waitingEvent // set only by the Assistant agent
    case suspended // set only by the Assistant agent or User on UI
    case resolved // set only by the Assistant agent or User on UI
    case cancelled // set only by the Assistant agent or User on UI
}
```

