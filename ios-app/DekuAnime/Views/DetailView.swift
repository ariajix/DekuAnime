import SwiftUI
import AVKit

// MARK: - Detail View

struct DetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSeason: Season?
    @State private var episodes: [Episode] = []
    @State private var showPlayer = false
    @State private var playerURL: URL?
    @State private var currentPlayingEpisode: Episode?
    @State private var isInWatchlist: Bool = false
    @State private var detailedAnime: Anime?
    @State private var isLoadingEpisodes: Bool = false
    @State private var isSynopsisExpanded: Bool = false
    
    let anime: Anime
    
    private var activeAnime: Anime {
        detailedAnime ?? anime
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // MARK: - 1. Hero Cover with Smooth Gradient Overlay & Title/Synopsis inside
                    ZStack(alignment: .bottomLeading) {
                        AsyncImage(url: activeAnime.posterURL) { phase in
                            switch phase {
                            case .empty:
                                Color(hex: "#1A1C22")
                                    .frame(height: 380)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 380)
                                    .clipped()
                            case .failure:
                                Color(hex: "#1A1C22")
                                    .frame(height: 380)
                                    .overlay {
                                        Image(systemName: "film")
                                            .font(.system(size: 44))
                                            .foregroundColor(.gray)
                                    }
                            @unknown default:
                                Color(hex: "#1A1C22")
                                    .frame(height: 380)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 380)
                        
                        // Gradient from top to bottom (darkens down)
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: Color.black.opacity(0.35), location: 0.35),
                                .init(color: Color.black.opacity(0.85), location: 0.70),
                                .init(color: Color(hex: "#090B10"), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 380)
                        
                        // Content in the dark area at bottom of the cover
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .center) {
                                Text(activeAnime.title)
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                
                                Spacer()
                                
                                Button(action: toggleWatchlist) {
                                    Image(systemName: isInWatchlist ? "bookmark.fill" : "bookmark")
                                        .font(.title3)
                                        .foregroundColor(isInWatchlist ? Color(hex: "#10B981") : .white)
                                        .padding(10)
                                        .background(Color.black.opacity(0.65))
                                        .clipShape(Circle())
                                }
                            }
                            
                            if !activeAnime.synopsis.isEmpty {
                                Text(activeAnime.synopsis)
                                    .font(.footnote)
                                    .foregroundColor(Color.white.opacity(0.85))
                                    .lineLimit(isSynopsisExpanded ? nil : 3)
                                    .onTapGesture {
                                        withAnimation(.easeInOut) {
                                            isSynopsisExpanded.toggle()
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    
                    // MARK: - 2. Genres
                    if !activeAnime.genres.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(activeAnime.genres, id: \.self) { genre in
                                    Text(genre)
                                        .font(.caption2.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color(hex: "#1A1C22"))
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    }
                    
                    // MARK: - 3. Seasons Slider (Horizontal Pill Slider)
                    if !activeAnime.seasons.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Staffeln & Filme")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(activeAnime.seasons) { season in
                                        let isSelected = (selectedSeason?.number == season.number)
                                        Button {
                                            selectedSeason = season
                                            loadSeasonEpisodes(season.number)
                                        } label: {
                                            Text(season.number == 0 ? "Filme" : "Staffel \(season.number)")
                                                .font(.subheadline.bold())
                                                .foregroundColor(isSelected ? .black : .white)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 18)
                                                        .fill(isSelected ? Color(hex: "#10B981") : Color(hex: "#1A1C22"))
                                                )
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 12)
                    }
                    
                    // MARK: - 4. Loading State
                    if isLoadingEpisodes {
                        HStack {
                            Spacer()
                            ProgressView("Lade Episoden...")
                                .tint(Color(hex: "#10B981"))
                                .foregroundColor(.white)
                                .padding(24)
                            Spacer()
                        }
                    }
                    
                    // MARK: - 5. Episode List with Real Names & Real Language Badges
                    if !episodes.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(episodes) { episode in
                                Button {
                                    Task {
                                        await playEpisode(episode)
                                    }
                                } label: {
                                    HStack(alignment: .center, spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(hex: "#141519"))
                                                .frame(width: 44, height: 44)
                                            Text("\(episode.number)")
                                                .font(.headline.bold())
                                                .foregroundColor(Color(hex: "#10B981"))
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(episode.title.isEmpty ? "Folge \(episode.number)" : episode.title)
                                                .font(.subheadline.bold())
                                                .foregroundColor(.white)
                                                .lineLimit(2)
                                            
                                            HStack(spacing: 6) {
                                                ForEach(episode.languageBadges, id: \.self) { badge in
                                                    Text(badge)
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(badge.contains("DUB") ? Color(hex: "#10B981") : Color.cyan)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.white.opacity(0.08))
                                                        .cornerRadius(4)
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "play.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(Color(hex: "#10B981"))
                                    }
                                    .padding(12)
                                    .background(Color(hex: "#101216"))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(Color(hex: "#090B10").ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .onAppear {
                isInWatchlist = StorageService.shared.isInWatchlist(anime: anime)
                selectedSeason = activeAnime.seasons.first
                episodes = selectedSeason?.episodes ?? []
                
                if !anime.url.isEmpty {
                    isLoadingEpisodes = episodes.isEmpty
                    Task {
                        if let online = try? await AniworldEngine.shared.fetchSeries(seriesPath: anime.url) {
                            await MainActor.run {
                                self.detailedAnime = online
                                self.selectedSeason = online.seasons.first
                                self.episodes = self.selectedSeason?.episodes ?? []
                                self.isLoadingEpisodes = false
                            }
                        } else {
                            await MainActor.run {
                                self.isLoadingEpisodes = false
                            }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showPlayer) {
                if let url = playerURL {
                    PlayerView(
                        url: url,
                        animeTitle: activeAnime.title,
                        episodeTitle: currentPlayingEpisode != nil ? "Staffel \(selectedSeason?.number ?? 1) Folge \(currentPlayingEpisode!.number): \(currentPlayingEpisode!.title)" : "Wiedergabe",
                        posterUrl: activeAnime.posterURL?.absoluteString ?? "",
                        seriesUrl: activeAnime.url,
                        episodeUrl: currentPlayingEpisode?.path ?? "",
                        seasonNumber: selectedSeason?.number ?? 1,
                        episodeNumber: currentPlayingEpisode?.number ?? 1,
                        initialTime: 0
                    )
                    .ignoresSafeArea()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleWatchlist() {
        isInWatchlist.toggle()
        if isInWatchlist {
            StorageService.shared.addToWatchlist(activeAnime)
        } else {
            StorageService.shared.removeFromWatchlist(activeAnime)
        }
    }
    
    private func loadSeasonEpisodes(_ seasonNum: Int) {
        isLoadingEpisodes = true
        Task {
            if let onlineEps = try? await AniworldEngine.shared.fetchSeasonEpisodes(seriesPath: activeAnime.url, seasonNumber: seasonNum), !onlineEps.isEmpty {
                await MainActor.run {
                    self.episodes = onlineEps
                    self.isLoadingEpisodes = false
                }
            } else {
                await MainActor.run {
                    self.episodes = selectedSeason?.episodes ?? []
                    self.isLoadingEpisodes = false
                }
            }
        }
    }
    
    private func playEpisode(_ episode: Episode) async {
        currentPlayingEpisode = episode
        do {
            let url = try await AniworldEngine.resolveStream(for: activeAnime, episode: episode)
            playerURL = url
            showPlayer = true
        } catch {
            playerURL = URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")
            showPlayer = true
        }
    }
}
