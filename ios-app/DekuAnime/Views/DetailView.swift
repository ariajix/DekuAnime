import SwiftUI
import AVKit

// MARK: - Models

struct Anime: Identifiable {
    let id: UUID
    let title: String
    let posterURL: URL
    let synopsis: String
    let genres: [String]
    let seasons: [Season]
    let isInWatchlist: Bool
}

struct Season: Identifiable, Hashable {
    let id: UUID
    let number: Int
    let episodes: [Episode]
}

struct Episode: Identifiable, Hashable {
    let id: UUID
    let number: Int
    let title: String
    let hasGermanDub: Bool
}

// MARK: - Engine Stub

enum AniworldEngine {
    static func resolveStream(for anime: Anime, episode: Episode) async throws -> URL {
        // Placeholder implementation – replace with real API call
        try await Task.sleep(nanoseconds: 500_000_000)
        return URL(string: "https://example.com/stream/\(anime.id)/\(episode.id).m3u8")!
    }
}

// MARK: - Player View

struct PlayerView: View {
    let url: URL
    
    var body: some View {
        VideoPlayer(player: AVPlayer(url: url))
            .ignoresSafeArea()
    }
}

// MARK: - Detail View

struct DetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSeason: Season?
    @State private var episodes: [Episode] = []
    @State private var showPlayer = false
    @State private var playerURL: URL?
    @State private var isInWatchlist: Bool = false
    @State private var watchedEpisodeIDs: Set<UUID> = []
    
    let anime: Anime
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Poster with gradient
                    ZStack(alignment: .bottom) {
                        AsyncImage(url: anime.posterURL) { phase in
                            switch phase {
                            case .empty:
                                Color.gray.opacity(0.3)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                            case .failure:
                                Color.red.opacity(0.3)
                            @unknown default:
                                Color.gray
                            }
                        }
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.8)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .frame(height: 200)
                    }
                    
                    // Title & Watchlist
                    HStack {
                        Text(anime.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button(action: toggleWatchlist) {
                            Image(systemName: isInWatchlist ? "bookmark.fill" : "bookmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    // Genres
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(anime.genres, id: \.self) { genre in
                                Text(genre)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Synopsis
                    Text(anime.synopsis)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    // Season Picker
                    if !anime.seasons.isEmpty {
                        Picker("Staffel", selection: $selectedSeason) {
                            ForEach(anime.seasons) { season in
                                Text("Staffel \(season.number)").tag(season as Season?)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedSeason) { newSeason in
                            episodes = newSeason?.episodes ?? []
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Episode List
                    if !episodes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(episodes) { episode in
                                Button {
                                    Task {
                                        await playEpisode(episode)
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("Episode \(episode.number)")
                                                .font(.headline)
                                            Text(episode.title)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if episode.hasGermanDub {
                                            Text("DE")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .padding(4)
                                                .background(Color.blue.opacity(0.2))
                                                .cornerRadius(4)
                                        }
                                        if watchedEpisodeIDs.contains(episode.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            .onAppear {
                isInWatchlist = anime.isInWatchlist
                selectedSeason = anime.seasons.first
                episodes = selectedSeason?.episodes ?? []
                loadWatchedEpisodes()
            }
            .fullScreenCover(isPresented: $showPlayer) {
                if let url = playerURL {
                    PlayerView(url: url)
                        .ignoresSafeArea()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleWatchlist() {
        isInWatchlist.toggle()
        // Persist change to your data store here
    }
    
    private func playEpisode(_ episode: Episode) async {
        do {
            let url = try await AniworldEngine.resolveStream(for: anime, episode: episode)
            playerURL = url
            showPlayer = true
            markEpisodeAsWatched(episode)
        } catch {
            // Handle error (e.g., show alert)
        }
    }
    
    private func markEpisodeAsWatched(_ episode: Episode) {
        watchedEpisodeIDs.insert(episode.id)
        saveWatchedEpisodes()
    }
    
    // MARK: - Persistence (simple UserDefaults example)
    
    private func loadWatchedEpisodes() {
        if let data = UserDefaults.standard.data(forKey: watchedKey),
           let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            watchedEpisodeIDs = ids
        }
    }
    
    private func saveWatchedEpisodes() {
        if let data = try? JSONEncoder().encode(watchedEpisodeIDs) {
            UserDefaults.standard.set(data, forKey: watchedKey)
        }
    }
    
    private var watchedKey: String {
        "watchedEpisodes_\(anime.id.uuidString)"
    }
}

// MARK: - Preview

#if DEBUG
struct DetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEpisodes = (1...12).map { i in
            Episode(id: UUID(),
                    number: i,
                    title: "Episode Title \(i)",
                    hasGermanDub: i % 3 == 0)
        }
        let sampleSeason = Season(id: UUID(), number: 1, episodes: sampleEpisodes)
        let sampleAnime = Anime(
            id: UUID(),
            title: "Sample Anime",
            posterURL: URL(string: "https://via.placeholder.com/300x450")!,
            synopsis: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed non risus.",
            genres: ["Action", "Adventure", "Fantasy"],
            seasons: [sampleSeason],
            isInWatchlist: false
        )
        DetailView(anime: sampleAnime)
    }
}
#endif