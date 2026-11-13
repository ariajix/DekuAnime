import Foundation

// MARK: - Engine

public actor AniworldEngine {
    public static let shared = AniworldEngine()
    
    private let session: URLSession
    private let baseURL = URL(string: "https://api.aniworld.example.com")!
    private let userAgent = "AniworldApp/1.0 (iOS; 17.0)"
    
    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": userAgent]
        self.session = URLSession(configuration: config)
    }
    
    // MARK: Public API
    
    public func fetchHomePage() async throws -> [HomeRow] {
        async let mega100 = fetchHomeRow(category: "mega-100", limit: 100)
        async let popularSeries = fetchHomeRow(category: "beliebte-serien", limit: 20)
        async let newReleases = fetchHomeRow(category: "neuerscheinungen", limit: 20)
        
        let rows = try await [mega100, popularSeries, newReleases]
        return rows
    }
    
    public func fetchGenre(slug: String, page: Int) async throws -> ([MediaItem], Bool) {
        var components = URLComponents(url: baseURL.appendingPathComponent("genre/\(slug)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)")
        ]
        let (data, _) = try await session.data(from: components.url!)
        let response = try JSONDecoder().decode(GenreResponse.self, from: data)
        return (response.items, response.hasMore)
    }
    
    public func search(keyword: String) async throws -> [MediaItem] {
        var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: keyword)
        ]
        let (data, _) = try await session.data(from: components.url!)
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        return response.items
    }
    
    public func fetchSeriesDetail(seriesUrl: String) async throws -> SeriesDetail {
        guard let url = URL(string: seriesUrl) else { throw URLError(.badURL) }
        let (data, _) = try await session.data(from: url)
        let detail = try JSONDecoder().decode(SeriesDetail.self, from: data)
        return detail
    }
    
    public static func resolveStream(for anime: Anime, episode: Episode) async throws -> URL {
        if let streamURL = episode.streamURL {
            return streamURL
        }
        return URL(string: "https://vdownload-53.com/stream/sample.m3u8")!
    }
    
    public func resolveStream(episodeUrl: String) async throws -> URL {
        guard let url = URL(string: episodeUrl) else { throw URLError(.badURL) }
        let (htmlData, _) = try await session.data(from: url)
        guard let html = String(data: htmlData, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
        
        // Attempt to find VOE encoded string inside a script tag
        let pattern = #"var\s+source\s*=\s*["']([^"']+)["'];"#
        guard let encoded = html.extractFirstGroup(pattern: pattern) else {
            throw StreamResolutionError.unableToFindEncodedSource
        }
        
        let decodedURLString = try decodeVOE(encoded)
        guard let streamURL = URL(string: decodedURLString) else {
            throw StreamResolutionError.invalidDecodedURL
        }
        return streamURL
    }
    
    // MARK: Private Helpers
    
    private func fetchHomeRow(category: String, limit: Int) async throws -> HomeRow {
        var components = URLComponents(url: baseURL.appendingPathComponent("home/\(category)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        let (data, _) = try await session.data(from: components.url!)
        let response = try JSONDecoder().decode(HomeRowResponse.self, from: data)
        return HomeRow(title: response.title, items: response.items)
    }
    
    private func decodeVOE(_ encoded: String) throws -> String {
        // Step 1: ROT13
        let rot13Decoded = encoded.rot13()
        
        // Step 2: Remove junk substrings
        let junkPatterns = ["@$", "^^", "~@", "%?", "*~", "!!", "#&"]
        var cleaned = rot13Decoded
        for junk in junkPatterns {
            cleaned = cleaned.replacingOccurrences(of: junk, with: "")
        }
        
        // Step 3: Base64 decode
        guard let firstData = Data(base64Encoded: cleaned) else {
            throw StreamResolutionError.invalidBase64
        }
        guard let firstString = String(data: firstData, encoding: .utf8) else {
            throw StreamResolutionError.invalidUTF8
        }
        
        // Step 4: Char shift -3
        let shifted = firstString.map { char -> Character in
            guard let scalar = char.unicodeScalars.first else { return char }
            let shiftedScalar = UnicodeScalar(scalar.value - 3)!
            return Character(shiftedScalar)
        }
        let shiftedString = String(shifted)
        
        // Step 5: Reverse
        let reversed = String(shiftedString.reversed())
        
        // Step 6: Base64 decode again
        guard let secondData = Data(base64Encoded: reversed) else {
            throw StreamResolutionError.invalidBase64
        }
        guard let jsonString = String(data: secondData, encoding: .utf8) else {
            throw StreamResolutionError.invalidUTF8
        }
        
        // Step 7: Parse JSON { "source": "url" }
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw StreamResolutionError.invalidJSON
        }
        let sourceObj = try JSONDecoder().decode(SourceWrapper.self, from: jsonData)
        return sourceObj.source
    }
}

// MARK: - Decoding Helpers

private extension String {
    func rot13() -> String {
        let a = Array(self.unicodeScalars)
        let transformed = a.map { scalar -> UnicodeScalar in
            let value = scalar.value
            switch value {
            case 65...90: // A-Z
                return UnicodeScalar(((value - 65 + 13) % 26) + 65)!
            case 97...122: // a-z
                return UnicodeScalar(((value - 97 + 13) % 26) + 97)!
            default:
                return scalar
            }
        }
        return String(String.UnicodeScalarView(transformed))
    }
}

// MARK: - Response Types

private struct HomeRowResponse: Decodable {
    let title: String
    let items: [MediaItem]
}

private struct GenreResponse: Decodable {
    let items: [MediaItem]
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case items = "results"
        case hasMore = "has_more"
    }
}

private struct SearchResponse: Decodable {
    let items: [MediaItem]
}

// MARK: - Stream Decoding Types

private struct SourceWrapper: Decodable {
    let source: String
}

// MARK: - Errors

public enum StreamResolutionError: Error {
    case unableToFindEncodedSource
    case invalidBase64
    case invalidUTF8
    case invalidJSON
    case invalidDecodedURL
}

// MARK: - Regex Helper

extension String {
    func extractFirstGroup(pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = self as NSString
        guard let match = regex.firstMatch(in: self, range: NSRange(location: 0, length: nsString.length)),
              match.numberOfRanges > 1 else { return nil }
        return nsString.substring(with: match.range(at: 1))
    }
}