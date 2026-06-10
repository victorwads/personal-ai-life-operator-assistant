import Foundation

@MainActor
final class GoogleContactsService {
    private let httpClient: GoogleWorkspaceHTTPClient

    init(httpClient: GoogleWorkspaceHTTPClient) {
        self.httpClient = httpClient
    }

    func listContacts(pageSize: Int = 100) async throws -> [GoogleContact] {
        let queryItems = [
            URLQueryItem(name: "pageSize", value: String(pageSize)),
            URLQueryItem(name: "personFields", value: "names,emailAddresses,phoneNumbers,organizations,photos")
        ]

        let url = "https://people.googleapis.com/v1/people/me/connections"
        let response: GoogleConnectionsResponse = try await httpClient.get(url, queryItems: queryItems)

        guard let connections = response.connections else {
            return []
        }

        return connections.map { conn in
            let nameObj = conn.names?.first
            let emailList = conn.emailAddresses?.compactMap { $0.value } ?? []
            let phoneList = conn.phoneNumbers?.compactMap { $0.value } ?? []
            let orgName = conn.organizations?.first?.name
            let photoUrl = conn.photos?.first?.url

            let displayName = nameObj?.displayName ?? emailList.first ?? conn.resourceName

            return GoogleContact(
                resourceName: conn.resourceName,
                displayName: displayName,
                givenName: nameObj?.givenName,
                familyName: nameObj?.familyName,
                emailAddresses: emailList,
                phoneNumbers: phoneList,
                organizationName: orgName,
                photoUrl: photoUrl
            )
        }
    }

    func searchContacts(query: String, pageSize: Int = 100) async throws -> [GoogleContact] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            return try await listContacts(pageSize: pageSize)
        }

        let url = "https://people.googleapis.com/v1/people:searchContacts"
        // Google People API caps searchContacts pageSize at 30.
        let queryItems = [
            URLQueryItem(name: "query", value: trimmedQuery),
            URLQueryItem(name: "readMask", value: "names,emailAddresses,phoneNumbers,organizations,photos"),
            URLQueryItem(name: "pageSize", value: String(min(pageSize, 30)))
        ]

        do {
            let response: GoogleSearchContactsResponse = try await httpClient.get(url, queryItems: queryItems)
            guard let results = response.results else {
                return []
            }

            return results.compactMap { result -> GoogleContact? in
                guard let conn = result.person else { return nil }
                let nameObj = conn.names?.first
                let emailList = conn.emailAddresses?.compactMap { $0.value } ?? []
                let phoneList = conn.phoneNumbers?.compactMap { $0.value } ?? []
                let orgName = conn.organizations?.first?.name
                let photoUrl = conn.photos?.first?.url

                let displayName = nameObj?.displayName ?? emailList.first ?? conn.resourceName

                return GoogleContact(
                    resourceName: conn.resourceName,
                    displayName: displayName,
                    givenName: nameObj?.givenName,
                    familyName: nameObj?.familyName,
                    emailAddresses: emailList,
                    phoneNumbers: phoneList,
                    organizationName: orgName,
                    photoUrl: photoUrl
                )
            }
        } catch {
            // Fall back to local search over connections list if server search fails (e.g., due to temporary restrictions)
            print("Google People API searchContacts failed: \(error.localizedDescription). Falling back to local connections search.")
            let contacts = try await listContacts(pageSize: max(pageSize, 100))
            let lowercasedQuery = trimmedQuery.lowercased()

            let filtered = contacts.filter { contact in
                contact.displayName.lowercased().contains(lowercasedQuery) ||
                (contact.givenName?.lowercased().contains(lowercasedQuery) ?? false) ||
                (contact.familyName?.lowercased().contains(lowercasedQuery) ?? false) ||
                contact.emailAddresses.contains { $0.lowercased().contains(lowercasedQuery) } ||
                contact.phoneNumbers.contains { $0.contains(lowercasedQuery) }
            }

            return Array(filtered.prefix(pageSize))
        }
    }
}

// MARK: - Decodable Helpers

struct GoogleConnectionsResponse: Decodable {
    struct Connection: Decodable {
        struct Name: Decodable {
            let displayName: String?
            let givenName: String?
            let familyName: String?
        }
        struct EmailAddress: Decodable {
            let value: String?
        }
        struct PhoneNumber: Decodable {
            let value: String?
        }
        struct Organization: Decodable {
            let name: String?
        }
        struct Photo: Decodable {
            let url: String?
            let `default`: Bool?
        }

        let resourceName: String
        let names: [Name]?
        let emailAddresses: [EmailAddress]?
        let phoneNumbers: [PhoneNumber]?
        let organizations: [Organization]?
        let photos: [Photo]?
    }

    let connections: [Connection]?
}

struct GoogleSearchContactsResponse: Decodable {
    struct SearchResult: Decodable {
        let person: GoogleConnectionsResponse.Connection?
    }
    let results: [SearchResult]?
}
