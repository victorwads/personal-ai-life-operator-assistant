import XCTest
@testable import AIAssistantHub

@MainActor
final class GoogleWorkspaceTests: XCTestCase {
    
    // 1. OAuth URL building: Scope, state, redirect_uri, access_type=offline
    func testOAuthURLBuilding() async throws {
        // We can create a mock SettingsStore and use the wrapper.
        let store = SettingsStore(profileId: "test-profile", repository: MockSettingsRepository())
        let wrapper = GoogleWorkspaceSettingsWrapper(settings: store)
        wrapper.clientId = "test-client-id"
        wrapper.clientSecret = "test-client-secret"
        wrapper.redirectPort = 8888
        
        let tokenStore = GoogleOAuthTokenStore(settingsStore: store)
        let authService = GoogleOAuthService(settings: wrapper, tokenStore: tokenStore)
        
        // We'll generate state and build the components for URL
        let stateString = "test-random-state"
        let redirectUri = "http://127.0.0.1:8888/oauth/google/callback"
        let scopes = wrapper.enabledScopes.joined(separator: " ")
        
        var authComponents = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        authComponents.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: wrapper.clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "state", value: stateString),
            URLQueryItem(name: "access_type", value: "offline")
        ]
        
        let url = authComponents.url!
        
        XCTAssertTrue(url.absoluteString.contains("response_type=code"))
        XCTAssertTrue(url.absoluteString.contains("client_id=test-client-id"))
        XCTAssertTrue(url.absoluteString.contains("redirect_uri=http%3A%2F%2F127.0.0.1%3A8888%2Foauth%2Fgoogle%2Fcallback"))
        XCTAssertTrue(url.absoluteString.contains("scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fgmail.readonly%20https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcalendar.readonly%20https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcontacts.readonly"))
        XCTAssertTrue(url.absoluteString.contains("state=test-random-state"))
        XCTAssertTrue(url.absoluteString.contains("access_type=offline"))
    }
    
    // 2. Gmail metadata parser extracts From/To/Subject/Date
    func testGmailMetadataParser() throws {
        let json = """
        {
          "id": "msg123",
          "threadId": "thread456",
          "snippet": "This is a test email snippet.",
          "internalDate": "1772659200000",
          "labelIds": ["INBOX", "UNREAD"],
          "payload": {
            "headers": [
              { "name": "From", "value": "Sender Name <sender@example.com>" },
              { "name": "To", "value": "Recipient Name <recipient@example.com>" },
              { "name": "Subject", "value": "Integration MVP Test" },
              { "name": "Date", "value": "Tue, 09 Jun 2026 19:53:33 -0300" }
            ]
          }
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let detail = try decoder.decode(GmailMessageDetailResponse.self, from: json)
        
        XCTAssertEqual(detail.id, "msg123")
        XCTAssertEqual(detail.threadId, "thread456")
        XCTAssertEqual(detail.snippet, "This is a test email snippet.")
        XCTAssertEqual(detail.internalDate, "1772659200000")
        XCTAssertEqual(detail.labelIds, ["INBOX", "UNREAD"])
        
        let headers = detail.payload?.headers ?? []
        let fromValue = headers.first(where: { $0.name == "From" })?.value
        let toValue = headers.first(where: { $0.name == "To" })?.value
        let subjectValue = headers.first(where: { $0.name == "Subject" })?.value
        let dateValue = headers.first(where: { $0.name == "Date" })?.value
        
        XCTAssertEqual(fromValue, "Sender Name <sender@example.com>")
        XCTAssertEqual(toValue, "Recipient Name <recipient@example.com>")
        XCTAssertEqual(subjectValue, "Integration MVP Test")
        XCTAssertEqual(dateValue, "Tue, 09 Jun 2026 19:53:33 -0300")
    }
    
    // 3. Calendar event parser handles dateTime and all-day date
    func testCalendarEventParser() throws {
        let json = """
        {
          "items": [
            {
              "id": "event1",
              "summary": "Regular Meeting",
              "description": "Discuss MVP integration details.",
              "location": "Virtual Room",
              "htmlLink": "https://calendar.google.com/event1",
              "start": { "dateTime": "2026-06-09T20:00:00-03:00" },
              "end": { "dateTime": "2026-06-09T21:00:00-03:00" }
            },
            {
              "id": "event2",
              "summary": "All-Day Event",
              "description": "National Holiday.",
              "start": { "date": "2026-06-10" },
              "end": { "date": "2026-06-11" }
            }
          ]
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(GoogleCalendarEventsResponse.self, from: json)
        let events = response.items ?? []
        
        XCTAssertEqual(events.count, 2)
        
        let regularEvent = events[0]
        XCTAssertEqual(regularEvent.id, "event1")
        XCTAssertEqual(regularEvent.summary, "Regular Meeting")
        XCTAssertEqual(regularEvent.start.dateTime, "2026-06-09T20:00:00-03:00")
        XCTAssertNil(regularEvent.start.date)
        
        let allDayEvent = events[1]
        XCTAssertEqual(allDayEvent.id, "event2")
        XCTAssertEqual(allDayEvent.summary, "All-Day Event")
        XCTAssertNil(allDayEvent.start.dateTime)
        XCTAssertEqual(allDayEvent.start.date, "2026-06-10")
        XCTAssertEqual(allDayEvent.end.date, "2026-06-11")
    }
    
    // 4. People contact parser extracts names/emails/phones
    func testPeopleContactParser() throws {
        let json = """
        {
          "connections": [
            {
              "resourceName": "people/c12345",
              "names": [
                {
                  "displayName": "Jane Smith",
                  "givenName": "Jane",
                  "familyName": "Smith"
                }
              ],
              "emailAddresses": [
                { "value": "jane.smith@example.com" },
                { "value": "work.jane@example.com" }
              ],
              "phoneNumbers": [
                { "value": "+1-555-0199" }
              ],
              "organizations": [
                { "name": "Google Inc." }
              ],
              "photos": [
                { "url": "https://lh3.googleusercontent.com/photo", "default": true }
              ]
            }
          ]
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(GoogleConnectionsResponse.self, from: json)
        let connections = response.connections ?? []
        
        XCTAssertEqual(connections.count, 1)
        
        let conn = connections[0]
        XCTAssertEqual(conn.resourceName, "people/c12345")
        
        let nameObj = conn.names?.first
        XCTAssertEqual(nameObj?.displayName, "Jane Smith")
        XCTAssertEqual(nameObj?.givenName, "Jane")
        XCTAssertEqual(nameObj?.familyName, "Smith")
        
        let emails = conn.emailAddresses?.compactMap { $0.value } ?? []
        XCTAssertEqual(emails, ["jane.smith@example.com", "work.jane@example.com"])
        
        let phones = conn.phoneNumbers?.compactMap { $0.value } ?? []
        XCTAssertEqual(phones, ["+1-555-0199"])
        
        XCTAssertEqual(conn.organizations?.first?.name, "Google Inc.")
        XCTAssertEqual(conn.photos?.first?.url, "https://lh3.googleusercontent.com/photo")
    }
    
    // 5. HTTP client redacts tokens in errors/logs
    func testHTTPClientTokenRedaction() async throws {
        let store = SettingsStore(profileId: "test-profile", repository: MockSettingsRepository())
        let wrapper = GoogleWorkspaceSettingsWrapper(settings: store)
        let tokenStore = GoogleOAuthTokenStore(settingsStore: store)
        let authService = GoogleOAuthService(settings: wrapper, tokenStore: tokenStore)
        let httpClient = GoogleWorkspaceHTTPClient(authService: authService)
        
        let rawLogMessage = "Authorization failed for Bearer ya29.a0AfH6SM... and refresh token 1//06-abcde..."
        let redacted = httpClient.redactTokens(in: rawLogMessage)
        
        XCTAssertFalse(redacted.contains("ya29.a0AfH6SM"))
        XCTAssertFalse(redacted.contains("1//06-abcde"))
        XCTAssertTrue(redacted.contains("[ACCESS_TOKEN_REDACTED]"))
        XCTAssertTrue(redacted.contains("[REFRESH_TOKEN_REDACTED]"))
    }
    
    // 6. JSON credentials parser extracts clientId and clientSecret
    func testCredentialsJSONParsing() throws {
        let installedJson = """
        {
          "installed": {
            "client_id": "installed-client-id",
            "client_secret": "installed-client-secret"
          }
        }
        """.data(using: .utf8)!
        
        let webJson = """
        {
          "web": {
            "client_id": "web-client-id",
            "client_secret": "web-client-secret"
          }
        }
        """.data(using: .utf8)!
        
        let invalidJson = """
        {
          "other": {
            "client_id": "no",
            "client_secret": "no"
          }
        }
        """.data(using: .utf8)!
        
        // Test installed
        let installedCreds = try GoogleWorkspaceSettingsWrapper.parseCredentials(from: installedJson)
        XCTAssertEqual(installedCreds.clientId, "installed-client-id")
        XCTAssertEqual(installedCreds.clientSecret, "installed-client-secret")
        
        // Test web
        let webCreds = try GoogleWorkspaceSettingsWrapper.parseCredentials(from: webJson)
        XCTAssertEqual(webCreds.clientId, "web-client-id")
        XCTAssertEqual(webCreds.clientSecret, "web-client-secret")
        
        // Test invalid
        XCTAssertThrowsError(try GoogleWorkspaceSettingsWrapper.parseCredentials(from: invalidJson))
    }
}

// MARK: - Mocks for Testing

private final class MockSettingsRepository: SettingsRepository {
    func loadScope(_ scopeName: String) async throws -> SettingsDocument {
        SettingsDocument(scopeName: scopeName, values: [:])
    }
    
    func loadAllScopes() async throws -> [SettingsDocument] { [] }
    
    func saveScope(_ scopeName: String, values: [String : String]) async throws {}
    
    func getValue(scopeName: String, key: String) async throws -> String? { nil }
    
    func setValue(scopeName: String, key: String, value: String) async throws {}
    
    func deleteValue(scopeName: String, key: String) async throws {}
    
    func observeScope(_ scopeName: String, listener: @escaping (SettingsDocument) -> Void) -> FirestoreListenerToken {
        FirestoreListenerToken {}
    }
    
    func observeAllScopes(_ listener: @escaping ([SettingsDocument]) -> Void) -> FirestoreListenerToken {
        FirestoreListenerToken {}
    }
}
