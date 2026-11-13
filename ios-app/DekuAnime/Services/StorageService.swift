import Foundation
import SwiftUI


// MARK: - HistoryEntry

public struct HistoryEntry: Codable, Identifiable, Hashable {
    public let id: UUID
    public var animeTitle: String
    public var posterUrl: String
    public var seriesUrl: String
    public var episodeUrl: String
    public var episodeTitle: String
    public var season: Int
    public var episode: Int
    public var position: Double          // Seconds into the episode
    public var duration: Double          // Total seconds of the episode
    public let dateAdded: Date
    
    public init(id: UUID = UUID(), animeTitle: String, posterUrl: String = "", seriesUrl: String = "", episodeUrl: String = "", episodeTitle: String = "", season: Int = 1, episode: Int = 1, position: Double = 0, duration: Double = 0, dateAdded: Date = Date()) {
        self.id = id
        self.animeTitle = animeTitle
        self.posterUrl = posterUrl
        self.seriesUrl = seriesUrl
        self.episodeUrl = episodeUrl
        self.episodeTitle = episodeTitle
        self.season = season
        self.episode = episode
        self.position = position
        self.duration = duration
        self.dateAdded = dateAdded
    }

    public init(mediaItem: MediaItem, season: Int, episode: Int, position: Double) {
        self.id = UUID()
        self.animeTitle = mediaItem.title
        self.posterUrl = mediaItem.posterUrl
        self.seriesUrl = mediaItem.url
        self.episodeUrl = "\(mediaItem.url)/staffel-\(season)/episode-\(episode)"
        self.episodeTitle = "Episode \(episode)"
        self.season = season
        self.episode = episode
        self.position = position
        self.duration = 0
        self.dateAdded = Date()
    }
}

// MARK: - PlaybackProgress

public struct PlaybackProgress: Codable, Hashable {
    public let season: Int
    public let episode: Int
    public var position: Double           // Seconds into the episode
    
    public init(season: Int, episode: Int, position: Double) {
        self.season = season
        self.episode = episode
        self.position = position
    }
}

// MARK: - StorageService

@MainActor
public final class StorageService: ObservableObject {
    public static let shared = StorageService()
    
    // MARK: - Public Published Properties
    
    @Published public private(set) var activeProfileName: String = "Deku" {
        didSet { persistActiveProfileName() }
    }
    
    @Published public private(set) var profileNames: [String] = [] {
        didSet { persistProfileNames() }
    }
    
    @Published public private(set) var history: [HistoryEntry] = [] {
        didSet { saveHistory() }
    }
    
    @Published public private(set) var watchlist: Set<String> = [] {
        didSet { saveWatchlist() }
    }
    
    @Published public private(set) var watchlistAnimes: [Anime] = []
    
    @Published public private(set) var episodeProgress: [String: PlaybackProgress] = [:] {
        didSet { saveProgress() }
    }
    
    // MARK: - Private Helpers
    
    private let fileManager = FileManager.default
    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var profileDirectoryURL: URL {
        documentsURL.appendingPathComponent("Profiles", isDirectory: true)
    }
    
    private var currentProfileURL: URL {
        profileDirectoryURL.appendingPathComponent(activeProfileName, isDirectory: true)
    }
    
    // MARK: - Init
    
    public init() {
        loadProfiles()
        loadActiveProfile()
    }
    
    // MARK: - Profile Management
    
    public func createProfile(named name: String) {
        guard !profileNames.contains(name) else { return }
        profileNames.append(name)
        activeProfileName = name
        try? fileManager.createDirectory(at: currentProfileURL, withIntermediateDirectories: true)
        resetCurrentProfileData()
    }
    
    public func selectProfile(named name: String) {
        guard profileNames.contains(name) else { return }
        activeProfileName = name
        loadCurrentProfileData()
    }
    
    public func deleteProfile(named name: String) {
        guard let index = profileNames.firstIndex(of: name) else { return }
        profileNames.remove(at: index)
        let url = profileDirectoryURL.appendingPathComponent(name, isDirectory: true)
        try? fileManager.removeItem(at: url)
        if activeProfileName == name {
            activeProfileName = profileNames.first ?? "Deku"
            loadCurrentProfileData()
        }
    }
    
    // MARK: - History
    
    public func addHistory(item: MediaItem, season: Int, episode: Int, position: Double) {
        recordWatch(
            animeTitle: item.title,
            posterUrl: item.posterUrl,
            seriesUrl: item.url,
            episodeUrl: "\(item.url)/staffel-\(season)/episode-\(episode)",
            episodeTitle: "Episode \(episode)",
            season: season,
            episode: episode,
            position: position,
            duration: 0
        )
    }
    
    public func recordWatch(
        animeTitle: String,
        posterUrl: String = "",
        seriesUrl: String = "",
        episodeUrl: String = "",
        episodeTitle: String = "",
        season: Int = 1,
        episode: Int = 1,
        position: Double = 0,
        duration: Double = 0
    ) {
        if let idx = history.firstIndex(where: {
            (!episodeUrl.isEmpty && $0.episodeUrl == episodeUrl) ||
            ($0.animeTitle == animeTitle && $0.season == season && $0.episode == episode)
        }) {
            var existing = history.remove(at: idx)
            existing.position = position
            if duration > 0 { existing.duration = duration }
            if !posterUrl.isEmpty { existing.posterUrl = posterUrl }
            history.insert(existing, at: 0)
        } else {
            let entry = HistoryEntry(
                animeTitle: animeTitle,
                posterUrl: posterUrl,
                seriesUrl: seriesUrl,
                episodeUrl: episodeUrl,
                episodeTitle: episodeTitle,
                season: season,
                episode: episode,
                position: position,
                duration: duration
            )
            history.insert(entry, at: 0)
        }
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
    }
    
    public func clearHistory() {
        history.removeAll()
    }
    
    // MARK: - Watchlist
    
    public func toggleWatchlist(item: MediaItem) {
        if watchlist.contains(item.id) {
            watchlist.remove(item.id)
        } else {
            watchlist.insert(item.id)
        }
    }
    
    public func removeFromWatchlist(_ anime: Anime) {
        watchlist.remove(anime.id.uuidString)
        watchlistAnimes.removeAll { $0.id == anime.id }
    }
    
    public func addToWatchlist(_ anime: Anime) {
        watchlist.insert(anime.id.uuidString)
        if !watchlistAnimes.contains(where: { $0.id == anime.id }) {
            watchlistAnimes.append(anime)
        }
    }
    
    public func isInWatchlist(item: MediaItem) -> Bool {
        watchlist.contains(item.id)
    }
    
    public func isInWatchlist(anime: Anime) -> Bool {
        watchlist.contains(anime.id.uuidString)
    }
    
    // MARK: - Playback Progress
    
    public func saveEpisodeProgress(item: MediaItem, season: Int, episode: Int, position: Double) {
        let key = progressKey(for: item.id, season: season, episode: episode)
        episodeProgress[key] = PlaybackProgress(season: season, episode: episode, position: position)
    }
    
    public func getEpisodeProgress(item: MediaItem, season: Int, episode: Int) -> Double? {
        let key = progressKey(for: item.id, season: season, episode: episode)
        return episodeProgress[key]?.position
    }
    
    // MARK: - Persistence
    
    private func persistActiveProfileName() {
        UserDefaults.standard.set(activeProfileName, forKey: "ActiveProfileName")
    }
    
    private func persistProfileNames() {
        UserDefaults.standard.set(profileNames, forKey: "ProfileNames")
    }
    
    private func loadProfiles() {
        if let saved = UserDefaults.standard.array(forKey: "ProfileNames") as? [String] {
            profileNames = saved
        } else {
            // Ensure at least the default profile exists
            profileNames = ["Deku"]
            persistProfileNames()
        }
    }
    
    private func loadActiveProfile() {
        if let saved = UserDefaults.standard.string(forKey: "ActiveProfileName") {
            activeProfileName = saved
        } else {
            activeProfileName = "Deku"
            persistActiveProfileName()
        }
        // Ensure directory exists
        try? fileManager.createDirectory(at: currentProfileURL, withIntermediateDirectories: true)
        loadCurrentProfileData()
    }
    
    private func resetCurrentProfileData() {
        history = []
        watchlist = []
        episodeProgress = [:]
    }
    
    private func loadCurrentProfileData() {
        loadHistory()
        loadWatchlist()
        loadProgress()
    }
    
    // MARK: History Persistence
    
    private var historyFileURL: URL { currentProfileURL.appendingPathComponent("history.json") }
    
    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: historyFileURL, options: .atomic)
    }
    
    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyFileURL) else {
            history = []
            return
        }
        history = (try? JSONDecoder().decode([HistoryEntry].self, from: data)) ?? []
    }
    
    // MARK: Watchlist Persistence
    
    private var watchlistFileURL: URL { currentProfileURL.appendingPathComponent("watchlist.json") }
    
    private func saveWatchlist() {
        let ids = Array(watchlist)
        guard let data = try? JSONEncoder().encode(ids) else { return }
        try? data.write(to: watchlistFileURL, options: .atomic)
    }
    
    private func loadWatchlist() {
        guard let data = try? Data(contentsOf: watchlistFileURL) else {
            watchlist = []
            return
        }
        if let ids = try? JSONDecoder().decode([String].self, from: data) {
            watchlist = Set(ids)
        } else {
            watchlist = []
        }
    }
    
    // MARK: Progress Persistence
    
    private var progressFileURL: URL { currentProfileURL.appendingPathComponent("progress.json") }
    
    private func saveProgress() {
        guard let data = try? JSONEncoder().encode(episodeProgress) else { return }
        try? data.write(to: progressFileURL, options: .atomic)
    }
    
    private func loadProgress() {
        guard let data = try? Data(contentsOf: progressFileURL) else {
            episodeProgress = [:]
            return
        }
        episodeProgress = (try? JSONDecoder().decode([String: PlaybackProgress].self, from: data)) ?? [:]
    }
    
    // MARK: Helpers
    
    private func progressKey(for mediaId: String, season: Int, episode: Int) -> String {
        "\(mediaId)_S\(season)E\(episode)"
    }
}