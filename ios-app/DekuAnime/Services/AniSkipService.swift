import Foundation

// MARK: - AniSkipService

/// A thread‑safe singleton service that resolves an anime's MAL ID and fetches its opening skip interval.
actor AniSkipService {
    
    // MARK: - Public API
    
    /// Shared singleton instance.
    static let shared = AniSkipService()
    
    /// Retrieves the opening (OP) skip interval for a given anime title and episode number.
    ///
    /// - Parameters:
    ///   - animeTitle: The title of the anime (case‑insensitive).
    ///   - episodeNumber: The episode number (1‑based).
    /// - Returns: A tuple containing the start and end times in seconds, or `nil` if no OP interval could be determined.
    func fetchIntroSkip(
        animeTitle: String,
        episodeNumber: Int
    ) async -> (startTime: Double, endTime: Double)? {
        guard let malId = await resolveMALID(for: animeTitle) else {
            return nil
        }
        return await fetchOPInterval(malId: malId, episodeNumber: episodeNumber)
    }
    
    // MARK: - Private Helpers
    
    /// Resolves the MyAnimeList (MAL) ID for a given anime title.
    ///
    /// Tries Anilist GraphQL first; if the result is missing or invalid, falls back to Jikan.
    private func resolveMALID(for title: String) async -> Int? {
        if let id = await fetchMALIDFromAnilist(title: title), id > 0 {
            return id
        }
        return await fetchMALIDFromJikan(title: title)
    }
    
    /// Performs the Anilist GraphQL request.
    private func fetchMALIDFromAnilist(title: String) async -> Int? {
        struct GraphQLRequest: Encodable {
            let query: String
            let variables: [String: String]
        }
        struct GraphQLResponse: Decodable {
            struct Data: Decodable {
                struct Media: Decodable {
                    let id: Int
                    let idMal: Int?
                }
                let Media: Media?
            }
            let data: Data?
        }
        
        let query = """
        query ($search: String!) {
          Media(search: $search, type: ANIME) {
            id
            idMal
          }
        }
        """
        let requestBody = GraphQLRequest(query: query, variables: ["search": title])
        guard let url = URL(string: "https://graphql.anilist.co") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            return nil
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(GraphQLResponse.self, from: data)
            return decoded.data?.Media?.idMal
        } catch {
            return nil
        }
    }
    
    /// Performs the Jikan fallback request.
    private func fetchMALIDFromJikan(title: String) async -> Int? {
        struct JikanResponse: Decodable {
            struct DataItem: Decodable {
                let mal_id: Int
            }
            let data: [DataItem]
        }
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.jikan.moe/v4/anime?q=\(encodedTitle)&limit=1") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(JikanResponse.self, from: data)
            return decoded.data.first?.mal_id
        } catch {
            return nil
        }
    }
    
    /// Calls AniSkip API and extracts the OP interval.
    private func fetchOPInterval(malId: Int, episodeNumber: Int) async -> (startTime: Double, endTime: Double)? {
        struct AniSkipResponse: Decodable {
            struct Result: Decodable {
                let skipType: String
                struct Interval: Decodable {
                    let start: Double
                    let end: Double
                }
                let interval: Interval
            }
            let results: [Result]
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.aniskip.com"
        components.path = "/v2/skip-times/\(malId)/\(episodeNumber)"
        components.queryItems = [
            URLQueryItem(name: "types", value: "op"),
            URLQueryItem(name: "types", value: "ed"),
            URLQueryItem(name: "episodeLength", value: "0")
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(AniSkipResponse.self, from: data)
            if let opResult = decoded.results.first(where: { $0.skipType.lowercased() == "op" }) {
                return (startTime: opResult.interval.start, endTime: opResult.interval.end)
            }
            return nil
        } catch {
            return nil
        }
    }
}

// MARK: - Example Usage (Remove in production)

#if DEBUG
@available(iOS 17.0, *)
func testAniSkipService() async {
    let result = await AniSkipService.shared.fetchIntroSkip(animeTitle: "Attack on Titan", episodeNumber: 1)
    if let interval = result {
        print("OP starts at \(interval.startTime)s, ends at \(interval.endTime)s")
    } else {
        print("No OP interval found.")
    }
}
#endif