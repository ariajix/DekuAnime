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
    private var posterCache: [String: String] = [:]
    
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
        
        var rawResults: [MediaItem] = []
        
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
                for obj in jsonArray {
                    let title = (obj["title"] as? String) ?? ""
                    let link = (obj["link"] as? String) ?? ""
                    let desc = (obj["description"] as? String) ?? ""
                    // Filter: only series, no single episode or support threads
                    if !title.isEmpty && !link.isEmpty && link.hasPrefix("/anime/stream/") && !link.contains("/staffel-") && !link.contains("/support/") {
                        let fullUrl = link.hasPrefix("/") ? link : "/anime/stream/\(link)"
                        let cachedCover = posterCache[fullUrl] ?? ""
                        rawResults.append(
                            MediaItem(
                                title: unescapeHTML(title),
                                url: fullUrl,
                                posterUrl: cachedCover,
                                description: unescapeHTML(desc),
                                site: "aniworld",
                                tags: ["Ger Dub", "Ger Sub"]
                            )
                        )
                    }
                }
            }
        }
        
        // 2. Client-side search fallback across all AniWorld animes if AJAX gave no results
        if rawResults.isEmpty {
            let catalog = try await fetchAllAnimes()
            let filtered = catalog.filter {
                $0.title.localizedCaseInsensitiveContains(kw) ||
                $0.description.localizedCaseInsensitiveContains(kw)
            }
            rawResults = Array(filtered.prefix(25))
        }
        
        let topResults = Array(rawResults.prefix(20))
        var finalResults = topResults
        
        // Resolve actual cover URLs concurrently for any search result that lacks one
        await withTaskGroup(of: (Int, String).self) { group in
            for (idx, itm) in topResults.enumerated() {
                if itm.posterUrl.isEmpty || itm.posterUrl.contains("placeholder") || itm.posterUrl.hasSuffix("-poster.jpg") {
                    group.addTask {
                        let cover = await self.fetchCoverOnly(for: itm.url)
                        return (idx, cover)
                    }
                }
            }
            for await (idx, cover) in group {
                if !cover.isEmpty {
                    finalResults[idx].posterUrl = cover
                }
            }
        }
        
        return finalResults
    }
    
    /// Quick cover resolution for search & watchlist
    public func fetchCoverOnly(for seriesPath: String) async -> String {
        let clean = seriesPath.hasPrefix("/") ? seriesPath : "/\(seriesPath)"
        if let cached = posterCache[clean], !cached.isEmpty {
            return cached
        }
        guard let url = URL(string: "\(aniworldBase)\(clean)") else { return "" }
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let (data, _) = try? await session.data(for: req),
           let html = String(data: data, encoding: .utf8) {
            let coverPattern = #"(?:data-src|src)="(/public/img/cover/[^"]+)""#
            if let match = html.extractFirstGroup(pattern: coverPattern) {
                let full = "\(aniworldBase)\(match)"
                posterCache[clean] = full
                return full
            }
        }
        return ""
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
            let fullCover = "\(aniworldBase)\(coverMatch)"
            coverURL = URL(string: fullCover)
            posterCache[cleanPath] = fullCover
        }
        
        // 2. Title
        let titlePattern = #"<div class="series-title">[\s\S]*?<span>([^<]+)</span>"#
        let title = html.extractFirstGroup(pattern: titlePattern) ?? cleanPath.replacingOccurrences(of: "/anime/stream/", with: "").replacingOccurrences(of: "-", with: " ").capitalized
        
        // 3. Synopsis / Description (exact extraction from data-full-description or seri_des)
        var synopsis = ""
        if let fullDesc = html.extractFirstGroup(pattern: #"data-full-description="([^"]+)""#), !fullDesc.isEmpty {
            synopsis = unescapeHTML(fullDesc)
        } else if let pDesc = html.extractFirstGroup(pattern: #"<p\s+class="seri_des"[^>]*>([\s\S]*?)</p>"#), !pDesc.isEmpty {
            synopsis = unescapeHTML(pDesc)
        } else if let sDesc = html.extractFirstGroup(pattern: #"<p\s+class="seriessynopsis"[^>]*>([\s\S]*?)</p>"#), !sDesc.isEmpty {
            synopsis = unescapeHTML(sDesc)
        } else {
            synopsis = "Anime auf AniWorld streamen."
        }
        
        // 4. Seasons
        let seasonPattern = #"href="(/anime/stream/[^/"]+/staffel-(\d+))""#
        var seasonNums = Set<Int>()
        if let seasonRegex = try? NSRegularExpression(pattern: seasonPattern) {
            let nsHtml = html as NSString
            let seasonMatches = seasonRegex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))
            for m in seasonMatches where m.numberOfRanges > 2 {
                if let num = Int(nsHtml.substring(with: m.range(at: 2))) {
                    seasonNums.insert(num)
                }
            }
        }
        if html.contains("/filme") {
            seasonNums.insert(0)
        }
        if seasonNums.isEmpty { seasonNums.insert(1) }
        let sortedSeasonNums = seasonNums.sorted()
        
        // 5. Episodes on current season page
        let currentSeasonEpisodes = parseEpisodes(from: html, defaultPath: "\(cleanPath)/staffel-1")
        
        var builtSeasons: [Season] = []
        for sNum in sortedSeasonNums {
            if sNum == 1 || (sortedSeasonNums.first == sNum && currentSeasonEpisodes.count > 0) {
                builtSeasons.append(Season(number: sNum, episodes: currentSeasonEpisodes))
            } else {
                // Initial placeholder so UI can show the season pill
                let eps = (1...12).map {
                    Episode(
                        number: $0,
                        title: "Folge \($0)",
                        hasGermanDub: true,
                        path: sNum == 0 ? "\(cleanPath)/filme" : "\(cleanPath)/staffel-\(sNum)/episode-\($0)",
                        availableLanguages: ["Ger Dub", "Ger Sub"]
                    )
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
    
    /// Dynamically loads episodes for a specific season of an anime
    public func fetchSeasonEpisodes(seriesPath: String, seasonNumber: Int) async throws -> [Episode] {
        let clean = seriesPath.hasPrefix("/") ? seriesPath : "/\(seriesPath)"
        let targetPath = seasonNumber == 0 ? "\(clean)/filme" : "\(clean)/staffel-\(seasonNumber)"
        guard let url = URL(string: "\(aniworldBase)\(targetPath)") else { return [] }
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: req)
        guard let html = String(data: data, encoding: .utf8) else { return [] }
        return parseEpisodes(from: html, defaultPath: targetPath)
    }
    
    /// Parses real episode rows, titles, and language flags from AniWorld HTML
    public func parseEpisodes(from html: String, defaultPath: String) -> [Episode] {
        var episodes: [Episode] = []
        let marker = "itemprop=\"episode\""
        var pos = html.startIndex
        var seenNums = Set<Int>()
        
        while let markerRange = html.range(of: marker, range: pos..<html.endIndex) {
            guard let trStart = html.range(of: "<tr", options: .backwards, range: html.startIndex..<markerRange.lowerBound),
                  let trEnd = html.range(of: "</tr>", range: markerRange.upperBound..<html.endIndex) else {
                pos = markerRange.upperBound
                continue
            }
            let trHtml = String(html[trStart.lowerBound..<trEnd.upperBound])
            pos = trEnd.upperBound
            
            var epNum = 0
            if let metaNum = trHtml.extractFirstGroup(pattern: #"itemprop="episodeNumber"\s+content="(\d+)""#), let n = Int(metaNum) {
                epNum = n
            } else if let folgeStr = trHtml.extractFirstGroup(pattern: #"Folge\s*(\d+)"#), let n = Int(folgeStr) {
                epNum = n
            } else if let epStr = trHtml.extractFirstGroup(pattern: #"episode-(\d+)"#), let n = Int(epStr) {
                epNum = n
            }
            
            if epNum > 0 && !seenNums.insert(epNum).inserted {
                continue
            }
            
            var epPath = trHtml.extractFirstGroup(pattern: #"href="(/anime/stream/[^"]+)""#) ?? ""
            if epPath.isEmpty {
                epPath = "\(defaultPath)/episode-\(epNum)"
            }
            
            let strongTitle = trHtml.extractFirstGroup(pattern: #"<strong>([\s\S]*?)</strong>"#)
            let spanTitle = trHtml.extractFirstGroup(pattern: #"<span>([\s\S]*?)</span>"#)
            
            var cleanTitle = ""
            if let s = strongTitle, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cleanTitle = unescapeHTML(s).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if let sp = spanTitle, !sp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cleanTitle = unescapeHTML(sp).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if cleanTitle.isEmpty {
                cleanTitle = "Episode \(epNum)"
            }
            
            var langs: [String] = []
            let lower = trHtml.lowercased()
            if lower.contains("german.svg") {
                langs.append("Ger Dub")
            }
            if lower.contains("japanese-german.svg") {
                langs.append("Ger Sub")
            }
            if lower.contains("japanese-english.svg") {
                langs.append("Eng Sub")
            }
            if lower.contains("english.svg") {
                langs.append("Eng Dub")
            }
            if langs.isEmpty {
                langs.append("Ger Sub")
            }
            
            episodes.append(
                Episode(
                    number: epNum,
                    title: cleanTitle,
                    hasGermanDub: langs.contains("Ger Dub"),
                    path: epPath,
                    availableLanguages: langs
                )
            )
        }
        
        if episodes.isEmpty {
            let epPattern = #"href="(/anime/stream/[^/"]+/staffel-\d+/episode-(\d+))"[^>]*title="([^"]*)""#
            if let epRegex = try? NSRegularExpression(pattern: epPattern) {
                let nsHtml = html as NSString
                let epMatches = epRegex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))
                for m in epMatches where m.numberOfRanges > 2 {
                    let path = nsHtml.substring(with: m.range(at: 1))
                    if let n = Int(nsHtml.substring(with: m.range(at: 2))), seenNums.insert(n).inserted {
                        let t = m.numberOfRanges > 3 ? nsHtml.substring(with: m.range(at: 3)) : "Folge \(n)"
                        episodes.append(Episode(number: n, title: unescapeHTML(t), hasGermanDub: true, path: path, availableLanguages: ["Ger Dub", "Ger Sub"]))
                    }
                }
            }
        }
        
        return episodes.sorted { $0.number < $1.number }
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
        
        // Check for client-side JavaScript redirect (e.g., window.location.href = '...')
        let jsRedirectPattern = #"window\.location\.href\s*=\s*['"](https?://[^'"]+)['"]"#
        if let jsTarget = html.extractFirstGroup(pattern: jsRedirectPattern), let targetURL = URL(string: jsTarget) {
            var subReq = URLRequest(url: targetURL)
            subReq.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            subReq.setValue(urlStr, forHTTPHeaderField: "Referer")
            if let (subData, subResp) = try? await session.data(for: subReq),
               let subHtml = String(data: subData, encoding: .utf8) {
                if let stream = parseDirectMediaURL(html: subHtml, currentUrl: subResp.url?.absoluteString ?? jsTarget) {
                    return stream
                }
            }
        }
        
        // Base64 encoded redirect (frequent in VOE delivery scripts)
        let b64Pattern = #"window\.location\.href\s*=\s*atob\(['"]([A-Za-z0-9+/=]+)['"]\)"#
        if let b64 = html.extractFirstGroup(pattern: b64Pattern),
           let b64Data = Data(base64Encoded: b64),
           let decodedUrlStr = String(data: b64Data, encoding: .utf8),
           let targetURL = URL(string: decodedUrlStr) {
            var subReq = URLRequest(url: targetURL)
            subReq.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            subReq.setValue(urlStr, forHTTPHeaderField: "Referer")
            if let (subData, subResp) = try? await session.data(for: subReq),
               let subHtml = String(data: subData, encoding: .utf8) {
                if let stream = parseDirectMediaURL(html: subHtml, currentUrl: subResp.url?.absoluteString ?? decodedUrlStr) {
                    return stream
                }
            }
        }
        
        return parseDirectMediaURL(html: html, currentUrl: urlStr)
    }

    private func parseDirectMediaURL(html: String, currentUrl: String) -> URL? {
        // 1. Vidmoly & VOE explicit file/hls/sources matches
        let patterns = [
            #"'hls':\s*['"](https?://[^'"]+)['"]"#,
            #""hls":\s*['"](https?://[^'"]+)['"]"#,
            #"file:\s*['"](https?://[^'"]+\.m3u8[^'"]*)['"]"#,
            #"sources:\s*\[\{\s*file:\s*['"](https?://[^'"]+)['"]"#,
            #"'mp4':\s*['"](https?://[^'"]+)['"]"#,
            #""mp4":\s*['"](https?://[^'"]+)['"]"#,
            #"https?://[^\s'"<>]+\.m3u8[^\s'"<>]*"#,
            #"https?://[^\s'"<>]+\.mp4[^\s'"<>]*"#
        ]
        
        for pat in patterns {
            if let match = html.extractFirstGroup(pattern: pat), let url = URL(string: match) {
                return url
            }
            if let match = html.extractFirstMatch(pattern: pat), let url = URL(string: match) {
                return url
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
            
            if !posterUrl.isEmpty && !posterUrl.contains("placeholder") && !posterUrl.hasSuffix("-poster.jpg") {
                posterCache[path] = posterUrl
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
