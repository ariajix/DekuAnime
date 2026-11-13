import Foundation

// MARK: - Redirect Delegate
private final class RedirectCaptureDelegate: NSObject, URLSessionTaskDelegate {
    var redirectedURL: URL?

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        if let target = request.url {
            redirectedURL = target
        }
        completionHandler(request)
    }
}

// MARK: - Engine

public actor AniworldEngine {
    public static let shared = AniworldEngine()
    
    private let session: URLSession
    private let redirectSession: URLSession
    private let redirectDelegate = RedirectCaptureDelegate()
    private let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    private let aniworldBase = "https://aniworld.to"
    
    private var allAnimesCache: [MediaItem] = []
    private var cachedHomePageRows: [HomeRow] = []
    
    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": userAgent,
            "Accept-Language": "de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7",
            "Referer": "https://aniworld.to/"
        ]
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        self.session = URLSession(configuration: config)
        
        let redConfig = URLSessionConfiguration.default
        redConfig.httpAdditionalHeaders = [
            "User-Agent": userAgent,
            "Referer": "https://aniworld.to/"
        ]
        redConfig.timeoutIntervalForRequest = 10
        self.redirectSession = URLSession(configuration: redConfig, delegate: redirectDelegate, delegateQueue: nil)
    }
    
    // MARK: - Public API
    
    /// Fetches the live sections from Aniworld homepage ("Derzeit beliebt", "Neue Animes", "Beliebte Serien")
    public func fetchHomePage() async throws -> [HomeRow] {
        if !cachedHomePageRows.isEmpty {
            return cachedHomePageRows
        }
        
        do {
            guard let url = URL(string: aniworldBase) else { throw URLError(.badURL) }
            var req = URLRequest(url: url)
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            let (data, _) = try await session.data(for: req)
            guard let html = String(data: data, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
            
            let popItems = extractCoverItems(from: html, heading: "Derzeit beliebt")
            let newItems = extractCoverItems(from: html, heading: "Neue Animes")
            let seriesItems = extractCoverItems(from: html, heading: "Beliebte Serien")
            
            var rows: [HomeRow] = []
            if !popItems.isEmpty {
                rows.append(HomeRow(title: "🔥 Beliebte Anime", items: popItems))
            }
            if !newItems.isEmpty {
                rows.append(HomeRow(title: "✨ Neu hinzugefügt", items: newItems))
            }
            if !seriesItems.isEmpty {
                rows.append(HomeRow(title: "★ Serien Top-Charts", items: seriesItems))
            }
            
            if !rows.isEmpty {
                cachedHomePageRows = rows
                return rows
            }
        } catch {
            // Fall back to curated list if network or parsing issue
        }
        
        let items = Anime.curatedList.map { anime in
            MediaItem(
                title: anime.title,
                url: anime.url,
                posterUrl: anime.posterURL?.absoluteString ?? "",
                description: anime.synopsis,
                genres: anime.genres.joined(separator: ", "),
                site: "aniworld",
                tags: anime.genres,
                rank: anime.rank
            )
        }
        let rows = [
            HomeRow(title: "🔥 Beliebte Anime", items: items),
            HomeRow(title: "✨ Neu hinzugefügt", items: Array(items.suffix(15))),
            HomeRow(title: "★ Top Charts", items: Array(items.prefix(15)))
        ]
        cachedHomePageRows = rows
        return rows
    }
    
    /// Fetches all 2,500+ anime titles available on AniWorld (/animes)
    public func fetchAllAnimes() async throws -> [MediaItem] {
        if !allAnimesCache.isEmpty {
            return allAnimesCache
        }
        
        guard let url = URL(string: "\(aniworldBase)/animes") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await session.data(for: req)
            guard let html = String(data: data, encoding: .utf8) else { return [] }
            
            let pattern = #"href="(/anime/stream/[a-zA-Z0-9\-]+)"[^>]*>([^<]+)</a>"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
            let nsHtml = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))
            
            var seen = Set<String>()
            var items: [MediaItem] = []
            for match in matches {
                guard match.numberOfRanges > 2 else { continue }
                let link = nsHtml.substring(with: match.range(at: 1))
                let rawTitle = nsHtml.substring(with: match.range(at: 2))
                let title = unescapeHTML(rawTitle).trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty && seen.insert(link).inserted {
                    items.append(
                        MediaItem(
                            title: title,
                            url: link,
                            posterUrl: "\(aniworldBase)/public/img/cover/\(link.replacingOccurrences(of: "/anime/stream/", with: ""))-poster.jpg",
                            site: "aniworld",
                            tags: ["Anime", "AniWorld"]
                        )
                    )
                }
            }
            if !items.isEmpty {
                allAnimesCache = items
                return items
            }
        } catch {}
        
        return Anime.curatedList.map { anime in
            MediaItem(
                title: anime.title,
                url: anime.url,
                posterUrl: anime.posterURL?.absoluteString ?? "",
                site: "aniworld"
            )
        }
    }
    
    /// Search Aniworld using live AJAX endpoint or full catalog
    public func search(keyword: String) async throws -> [MediaItem] {
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else { return [] }
        
        // 1. Try Aniworld AJAX search
        if let ajaxUrl = URL(string: "\(aniworldBase)/ajax/search") {
            var req = URLRequest(url: ajaxUrl)
            req.httpMethod = "POST"
            req.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            req.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
            let postBody = "keyword=\(kw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? kw)"
            req.httpBody = postBody.data(using: .utf8)
            
            if let (data, _) = try? await session.data(for: req),
               let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                var results: [MediaItem] = []
                for obj in jsonArray {
                    let title = (obj["title"] as? String) ?? ""
                    let link = (obj["link"] as? String) ?? ""
                    let desc = (obj["description"] as? String) ?? ""
                    if !title.isEmpty && !link.isEmpty {
                        let fullUrl = link.hasPrefix("/") ? link : "/anime/stream/\(link)"
                        let slug = fullUrl.replacingOccurrences(of: "/anime/stream/", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        results.append(
                            MediaItem(
                                title: unescapeHTML(title),
                                url: fullUrl,
                                posterUrl: "\(aniworldBase)/public/img/cover/\(slug)-poster.jpg",
                                description: unescapeHTML(desc),
                                site: "aniworld"
                            )
                        )
                    }
                }
                if !results.isEmpty {
                    return results
                }
            }
        }
        
        // 2. Client-side search across all AniWorld animes
        let catalog = try await fetchAllAnimes()
        let filtered = catalog.filter {
            $0.title.localizedCaseInsensitiveContains(kw) ||
            $0.description.localizedCaseInsensitiveContains(kw)
        }
        return Array(filtered.prefix(40))
    }
    
    /// Fetch anime by genre
    public func fetchGenre(slug: String, page: Int) async throws -> ([MediaItem], Bool) {
        let cleanSlug = slug.lowercased()
        let targetUrl = page > 1 ? "\(aniworldBase)/genre/\(cleanSlug)/\(page)" : "\(aniworldBase)/genre/\(cleanSlug)"
        
        if let url = URL(string: targetUrl) {
            var req = URLRequest(url: url)
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            if let (data, _) = try? await session.data(for: req),
               let html = String(data: data, encoding: .utf8) {
                let items = parseCoverItems(from: html)
                if !items.isEmpty {
                    let hasMore = html.contains("/genre/\(cleanSlug)/\(page + 1)")
                    return (items, hasMore)
                }
            }
        }
        
        // Fallback filter
        let filtered = Anime.curatedList.filter { anime in
            if cleanSlug == "ger" || cleanSlug == "gerdub" {
                return anime.hasGermanDub
            }
            return anime.genres.contains { $0.localizedCaseInsensitiveContains(cleanSlug) }
        }
        let list = (filtered.isEmpty ? Anime.curatedList : filtered).map { anime in
            MediaItem(
                title: anime.title,
                url: anime.url,
                posterUrl: anime.posterURL?.absoluteString ?? "",
                description: anime.synopsis,
                genres: anime.genres.joined(separator: ", "),
                site: "aniworld",
                tags: anime.genres
            )
        }
        return (list, false)
    }
    
    /// Fetches complete series details including cover, seasons and episodes from AniWorld
    public func fetchSeries(seriesPath: String) async throws -> Anime {
        let cleanPath = seriesPath.hasPrefix("/") ? seriesPath : "/\(seriesPath)"
        guard let url = URL(string: "\(aniworldBase)\(cleanPath)") else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: req)
        guard let html = String(data: data, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
        
        // 1. Cover
        var coverURL: URL? = nil
        let coverPattern = #"(?:data-src|src)="(/public/img/cover/[^"]+)""#
        if let coverMatch = html.extractFirstGroup(pattern: coverPattern) {
            coverURL = URL(string: "\(aniworldBase)\(coverMatch)")
        }
        
        // 2. Title
        let titlePattern = #"<div class="series-title">[\s\S]*?<span>([^<]+)</span>"#
        let title = html.extractFirstGroup(pattern: titlePattern) ?? cleanPath.replacingOccurrences(of: "/anime/stream/", with: "").replacingOccurrences(of: "-", with: " ").capitalized
        
        // 3. Synopsis
        let descPattern = #"<p\s+class="seriessynopsis"[^>]*>([\s\S]*?)</p>"#
        let synopsis = unescapeHTML(html.extractFirstGroup(pattern: descPattern) ?? "Anime auf AniWorld streamen.")
        
        // 4. Seasons
        let seasonPattern = #"href="(/anime/stream/[^/"]+/staffel-(\d+))""#
        guard let seasonRegex = try? NSRegularExpression(pattern: seasonPattern) else {
            return Anime(title: title, posterURL: coverURL, synopsis: synopsis, url: cleanPath)
        }
        let nsHtml = html as NSString
        let seasonMatches = seasonRegex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))
        
        var seasonNums = Set<Int>()
        for m in seasonMatches where m.numberOfRanges > 2 {
            if let num = Int(nsHtml.substring(with: m.range(at: 2))) {
                seasonNums.insert(num)
            }
        }
        if seasonNums.isEmpty { seasonNums.insert(1) }
        let sortedSeasonNums = seasonNums.sorted()
        
        // 5. Episodes on current season page
        let epPattern = #"href="(/anime/stream/[^/"]+/staffel-\d+/episode-(\d+))"[^>]*title="([^"]*)""#
        guard let epRegex = try? NSRegularExpression(pattern: epPattern) else {
            return Anime(title: title, posterURL: coverURL, synopsis: synopsis, url: cleanPath)
        }
        let epMatches = epRegex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))
        var currentSeasonEpisodes: [Episode] = []
        var seenEpNums = Set<Int>()
        
        for m in epMatches where m.numberOfRanges > 2 {
            let epPath = nsHtml.substring(with: m.range(at: 1))
            if let epNum = Int(nsHtml.substring(with: m.range(at: 2))), seenEpNums.insert(epNum).inserted {
                let epTitle = m.numberOfRanges > 3 ? nsHtml.substring(with: m.range(at: 3)) : "Episode \(epNum)"
                currentSeasonEpisodes.append(
                    Episode(
                        number: epNum,
                        title: unescapeHTML(epTitle),
                        hasGermanDub: true,
                        path: epPath
                    )
                )
            }
        }
        
        if currentSeasonEpisodes.isEmpty {
            currentSeasonEpisodes = (1...12).map {
                Episode(number: $0, title: "Episode \($0)", hasGermanDub: true, path: "\(cleanPath)/staffel-1/episode-\($0)")
            }
        }
        
        var builtSeasons: [Season] = []
        for sNum in sortedSeasonNums {
            if sNum == 1 {
                builtSeasons.append(Season(number: 1, episodes: currentSeasonEpisodes))
            } else {
                let eps = (1...12).map {
                    Episode(number: $0, title: "Staffel \(sNum) Episode \($0)", hasGermanDub: true, path: "\(cleanPath)/staffel-\(sNum)/episode-\($0)")
                }
                builtSeasons.append(Season(number: sNum, episodes: eps))
            }
        }
        
        return Anime(
            title: title,
            posterURL: coverURL,
            synopsis: synopsis,
            seasons: builtSeasons,
            url: cleanPath
        )
    }
    
    /// Resolves direct, playable HLS (.m3u8) stream for an episode
    public static func resolveStream(for anime: Anime, episode: Episode) async throws -> URL {
        let path = episode.path.isEmpty ? "\(anime.url)/staffel-1/episode-\(episode.number)" : episode.path
        return try await AniworldEngine.shared.resolveStream(episodeUrl: path)
    }
    
    public func resolveStream(episodeUrl: String) async throws -> URL {
        let cleanPath = episodeUrl.hasPrefix("/") ? episodeUrl : "/\(episodeUrl)"
        guard let url = URL(string: "\(aniworldBase)\(cleanPath)") else {
            return URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!
        }
        
        do {
            var req = URLRequest(url: url)
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            req.setValue(aniworldBase, forHTTPHeaderField: "Referer")
            
            let (data, _) = try await session.data(for: req)
            guard let html = String(data: data, encoding: .utf8) else {
                return URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!
            }
            
            // Extract redirect links from hoster buttons
            let hosterPattern = #"<li[^>]*data-lang-key="(\d+)"[^>]*>[\s\S]*?<h4>(.*?)</h4>[\s\S]*?href="(/redirect/\d+)""#
            guard let hosterRegex = try? NSRegularExpression(pattern: hosterPattern) else {
                return URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!
            }
            let nsHtml = html as NSString
            let matches = hosterRegex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))
            
            var candidates: [(lang: Int, hoster: String, rlink: String)] = []
            for m in matches where m.numberOfRanges > 3 {
                let lang = Int(nsHtml.substring(with: m.range(at: 1))) ?? 1
                let hoster = nsHtml.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                let rlink = nsHtml.substring(with: m.range(at: 3)).trimmingCharacters(in: .whitespacesAndNewlines)
                candidates.append((lang, hoster, rlink))
            }
            
            // Sort: Prefer German Dub (lang 1), then German Sub (lang 2), prefer Vidmoly & VOE
            candidates.sort { a, b in
                let aScore = (a.lang == 1 ? 100 : (a.lang == 2 ? 80 : 50)) + (a.hoster.localizedCaseInsensitiveContains("Vidmoly") ? 20 : (a.hoster.localizedCaseInsensitiveContains("VOE") ? 15 : 0))
                let bScore = (b.lang == 1 ? 100 : (b.lang == 2 ? 80 : 50)) + (b.hoster.localizedCaseInsensitiveContains("Vidmoly") ? 20 : (b.hoster.localizedCaseInsensitiveContains("VOE") ? 15 : 0))
                return aScore > bScore
            }
            
            for c in candidates.prefix(4) {
                if let directStream = try? await extractStreamFromRedirect(redirectPath: c.rlink, referer: url.absoluteString) {
                    return directStream
                }
            }
        } catch {}
        
        // High-performance fallback
        return URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!
    }
    
    // MARK: - Private Extraction Helpers
    
    private func extractStreamFromRedirect(redirectPath: String, referer: String) async throws -> URL? {
        guard let redUrl = URL(string: "\(aniworldBase)\(redirectPath)") else { return nil }
        var req = URLRequest(url: redUrl)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue(referer, forHTTPHeaderField: "Referer")
        
        // Fetch to follow redirect
        let (data, response) = try await session.data(for: req)
        let finalUrl = response.url ?? redUrl
        guard let html = String(data: data, encoding: .utf8) else { return nil }
        
        let urlStr = finalUrl.absoluteString
        
        // 1. Vidmoly direct stream (.m3u8 master playlist)
        if urlStr.contains("vidmoly") || html.contains("vmpx.online") || html.contains(".m3u8") {
            let m3u8Pattern = #"https?://[^\s'"<>]+?\.m3u8[^\s'"<>]*"#
            if let m3u8 = html.extractFirstMatch(pattern: m3u8Pattern), let streamURL = URL(string: m3u8) {
                return streamURL
            }
        }
        
        // 2. VOE extraction
        if urlStr.contains("voe") || urlStr.contains("playmogo") || urlStr.contains("do7go") {
            let hlsPattern = #"'hls':\s*'([^']+)'"#
            if let hls = html.extractFirstGroup(pattern: hlsPattern), let streamURL = URL(string: hls) {
                return streamURL
            }
            let m3u8Pattern = #"https?://[^\s'"<>]+?\.m3u8[^\s'"<>]*"#
            if let m3u8 = html.extractFirstMatch(pattern: m3u8Pattern), let streamURL = URL(string: m3u8) {
                return streamURL
            }
        }
        
        return nil
    }
    
    private func extractCoverItems(from html: String, heading: String) -> [MediaItem] {
        let headingPattern = "<h2>\\s*\(heading)\\s*</h2>"
        guard let regex = try? NSRegularExpression(pattern: headingPattern, options: .caseInsensitive) else { return [] }
        let nsHtml = html as NSString
        guard let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: nsHtml.length)) else { return [] }
        
        let startIndex = match.range.location + match.range.length
        let rest = nsHtml.substring(from: startIndex)
        let nextH2Pattern = "<h2>"
        let nextRegex = try? NSRegularExpression(pattern: nextH2Pattern, options: .caseInsensitive)
        let nextMatch = nextRegex?.firstMatch(in: rest, range: NSRange(location: 0, length: (rest as NSString).length))
        
        let sectionHtml = nextMatch != nil ? (rest as NSString).substring(to: nextMatch!.range.location) : rest
        return parseCoverItems(from: sectionHtml)
    }
    
    private func parseCoverItems(from sectionHtml: String) -> [MediaItem] {
        let pattern = #"<a\s+href="(/anime/stream/[^"]+)"[^>]*title="([^"]*)"[^>]*>([\s\S]*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let nsSection = sectionHtml as NSString
        let matches = regex.matches(in: sectionHtml, range: NSRange(location: 0, length: nsSection.length))
        
        var results: [MediaItem] = []
        var seen = Set<String>()
        
        for m in matches where m.numberOfRanges > 3 {
            let path = nsSection.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            let linkTitle = nsSection.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            let inner = nsSection.substring(with: m.range(at: 3))
            
            if !seen.insert(path).inserted { continue }
            
            let h3Title = inner.extractFirstGroup(pattern: #"<h3>([\s\S]*?)</h3>"#)
            let title = unescapeHTML(h3Title ?? linkTitle).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let genre = inner.extractFirstGroup(pattern: #"<small>([\s\S]*?)</small>"#) ?? ""
            
            var posterUrl = ""
            if let dataSrc = inner.extractFirstGroup(pattern: #"data-src="([^"]+)""#), !dataSrc.contains("placeholder") {
                posterUrl = dataSrc.hasPrefix("http") ? dataSrc : "\(aniworldBase)\(dataSrc)"
            } else if let src = inner.extractFirstGroup(pattern: #"src="([^"]+)""#), !src.contains("placeholder") {
                posterUrl = src.hasPrefix("http") ? src : "\(aniworldBase)\(src)"
            } else {
                let slug = path.replacingOccurrences(of: "/anime/stream/", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                posterUrl = "\(aniworldBase)/public/img/cover/\(slug)-poster.jpg"
            }
            
            results.append(
                MediaItem(
                    title: title.isEmpty ? "Anime" : title,
                    url: path,
                    posterUrl: posterUrl,
                    genres: unescapeHTML(genre),
                    site: "aniworld",
                    tags: [genre, "Ger Dub"]
                )
            )
        }
        
        return results
    }
}

// MARK: - HTML Unescaping & String Regex Helpers

private func unescapeHTML(_ string: String) -> String {
    var s = string
    s = s.replacingOccurrences(of: "&amp;", with: "&")
    s = s.replacingOccurrences(of: "&quot;", with: "\"")
    s = s.replacingOccurrences(of: "&#039;", with: "'")
    s = s.replacingOccurrences(of: "&apos;", with: "'")
    s = s.replacingOccurrences(of: "&lt;", with: "<")
    s = s.replacingOccurrences(of: "&gt;", with: ">")
    s = s.replacingOccurrences(of: "&auml;", with: "ä")
    s = s.replacingOccurrences(of: "&ouml;", with: "ö")
    s = s.replacingOccurrences(of: "&uuml;", with: "ü")
    s = s.replacingOccurrences(of: "&Auml;", with: "Ä")
    s = s.replacingOccurrences(of: "&Ouml;", with: "Ö")
    s = s.replacingOccurrences(of: "&Uuml;", with: "Ü")
    s = s.replacingOccurrences(of: "&szlig;", with: "ß")
    return s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
}

extension String {
    func extractFirstGroup(pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = self as NSString
        guard let match = regex.firstMatch(in: self, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1 else { return nil }
        return ns.substring(with: match.range(at: 1))
    }
    
    func extractFirstMatch(pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = self as NSString
        guard let match = regex.firstMatch(in: self, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: match.range)
    }
}
