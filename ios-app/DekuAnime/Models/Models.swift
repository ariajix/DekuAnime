import Foundation

public struct MediaItem: Identifiable, Codable, Equatable, Hashable {
    public var id: String { url.isEmpty ? title : url }
    public let title: String
    public let url: String
    public let posterUrl: String
    public let description: String
    public let genres: String
    public let rating: String
    public let site: String
    public let tags: [String]

    public init(
        title: String,
        url: String,
        posterUrl: String = "",
        description: String = "",
        genres: String = "",
        rating: String = "",
        site: String = "aniworld",
        tags: [String] = []
    ) {
        self.title = title
        self.url = url
        self.posterUrl = posterUrl
        self.description = description
        self.genres = genres
        self.rating = rating
        self.site = site
        self.tags = tags
    }

    public var isGerDub: Boolean {
        tags.contains { $0.localizedCaseInsensitiveContains("Ger") && !$0.localizedCaseInsensitiveContains("Sub") }
    }
}

public typealias Boolean = Bool

public struct HomeRow: Identifiable, Codable {
    public var id: String { title }
    public let title: String
    public let items: [MediaItem]
}

public struct SeasonInfo: Identifiable, Codable {
    public var id: String { url }
    public let seasonNumber: Int
    public let title: String
    public let url: String
    public let isMovie: Bool

    public init(seasonNumber: Int, title: String, url: String, isMovie: Bool = false) {
        self.seasonNumber = seasonNumber
        self.title = title
        self.url = url
        self.isMovie = isMovie
    }
}

public struct EpisodeInfo: Identifiable, Codable {
    public var id: String { url }
    public let episodeNumber: Int
    public let titleGerman: String
    public let titleRomaji: String
    public let url: String
    public var providers: [String: [String]] // ProviderName -> [Language/RedirectUrls]

    public init(
        episodeNumber: Int,
        titleGerman: String,
        titleRomaji: String = "",
        url: String,
        providers: [String: [String]] = [:]
    ) {
        self.episodeNumber = episodeNumber
        self.titleGerman = titleGerman
        self.titleRomaji = titleRomaji
        self.url = url
        self.providers = providers
    }
}

public struct SeriesDetail: Codable {
    public let item: MediaItem
    public let synopsis: String
    public let seasons: [SeasonInfo]
    public let episodes: [EpisodeInfo]
}

public struct StreamResult: Codable {
    public let streamUrl: String
    public let provider: String
    public let isHls: Bool
    public let headers: [String: String]
}

public struct UserProfile: Identifiable, Codable, Equatable {
    public var id: String { name }
    public var name: String
    public var avatar: String
    public var createdAt: Date

    public init(name: String, avatar: String = "", createdAt: Date = Date()) {
        self.name = name
        self.avatar = avatar
        self.createdAt = createdAt
    }
}

public struct EpisodeProgress: Codable {
    public let seriesUrl: String
    public let seasonNum: Int
    public let episodeNum: Int
    public let positionSeconds: Double
    public let durationSeconds: Double
    public let updatedAt: Date
}

