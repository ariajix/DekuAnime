import SwiftUI



// MARK: - Models

struct GenreAnime: Identifiable, Hashable {
    let id: UUID = UUID()
    let title: String
    let imageURL: URL?
    let isGermanDub: Bool
}

// MARK: - Dummy Data Provider

class AnimeService {
    static let shared = AnimeService()
    
    private let allGenres = [
        "Action", "Abenteuer", "Komödie", "Fighting‑Shounen", "Drama",
        "Fantasy", "Sci‑Fi", "Mystery", "Horror", "Slice‑of‑Life"
    ]
    
    func fetchGenres() -> [String] {
        allGenres
    }
    
    // Simulated network fetch with pagination
    func fetchGenreAnime(
        genre: String,
        germanDubOnly: Bool,
        offset: Int,
        limit: Int
    ) async throws -> [GenreAnime] {
        let matching = Anime.curatedList.filter { anime in
            let matchesGenre = genre.isEmpty || anime.genres.contains { g in
                g.localizedCaseInsensitiveContains(genre) ||
                (genre.contains("Shounen") && (g.contains("Shonen") || g.contains("Action")))
            }
            let matchesDub = !germanDubOnly || anime.hasGermanDub
            return matchesGenre && matchesDub
        }
        let list = matching.isEmpty ? Anime.curatedList : matching
        let paged = list.dropFirst(offset).prefix(limit)
        return paged.map { anime in
            GenreAnime(
                title: anime.title,
                imageURL: anime.posterURL,
                isGermanDub: anime.hasGermanDub
            )
        }
    }
}

// MARK: - ViewModel

@MainActor
class GenresViewModel: ObservableObject {
    @Published var selectedGenre: String = ""
    @Published var germanDubOnly: Bool = false
    @Published var animeList: [GenreAnime] = []
    @Published var isLoading: Bool = false
    @Published var hasMore: Bool = true
    
    private let pageSize = 30
    private var currentOffset = 0
    
    private let service = AnimeService.shared
    
    var availableGenres: [String] {
        service.fetchGenres()
    }
    
    func selectGenre(_ genre: String) {
        selectedGenre = genre
        resetAndLoad()
    }
    
    func toggleGermanDub() {
        germanDubOnly.toggle()
        resetAndLoad()
    }
    
    private func resetAndLoad() {
        animeList = []
        currentOffset = 0
        hasMore = true
        Task { await loadMore() }
    }
    
    func loadMore() async {
        guard !isLoading, hasMore, !selectedGenre.isEmpty else { return }
        isLoading = true
        do {
            let newItems = try await service.fetchGenreAnime(
                genre: selectedGenre,
                germanDubOnly: germanDubOnly,
                offset: currentOffset,
                limit: pageSize
            )
            animeList.append(contentsOf: newItems)
            currentOffset += newItems.count
            hasMore = newItems.count == pageSize
        } catch {
            // Handle error appropriately in a real app
            print("Failed to fetch anime: \(error)")
            hasMore = false
        }
        isLoading = false
    }
}

// MARK: - AnimeCardView (Placeholder)

private struct GenreAnimeCardView: View {
    let anime: GenreAnime
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            AsyncImage(url: anime.imageURL) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Color(hex: "1A1C22")
                        ProgressView().tint(Color(hex: "10B981"))
                    }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    ZStack {
                        Color(hex: "1A1C22")
                        Image(systemName: "film")
                            .foregroundColor(.gray)
                    }
                @unknown default:
                    Color(hex: "1A1C22")
                }
            }
            .frame(height: 160)
            .clipped()
            .cornerRadius(8)
            
            Text(anime.title)
                .font(.caption.bold())
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 4)
            
            Text(anime.isGermanDub ? "Ger Dub" : "Ger Sub")
                .font(.caption2)
                .foregroundColor(anime.isGermanDub ? Color(hex: "10B981") : .gray)
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
        }
        .background(Color(hex: "141519"))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 2)
    }
}

// MARK: - GenresView

struct GenresView: View {
    @StateObject private var viewModel = GenresViewModel()
    
    // Grid layout for genre buttons (2 columns)
    private let genreColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    // Grid layout for anime cards (2 columns)
    private let animeColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // MARK: Genre Selection (2‑column menu)
                LazyVGrid(columns: genreColumns, spacing: 12) {
                    ForEach(viewModel.availableGenres, id: \.self) { genre in
                        Button(action: {
                            viewModel.selectGenre(genre)
                        }) {
                            Text(genre)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(viewModel.selectedGenre == genre ? .white : Color(hex: "#50C878"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(viewModel.selectedGenre == genre ? Color(hex: "#50C878") : Color(hex: "#1E2127"))
                                )
                        }
                    }
                }
                .padding(.horizontal)
                
                // MARK: German Dub Filter
                Toggle(isOn: $viewModel.germanDubOnly) {
                    Text("Nur Ger Dub")
                        .foregroundColor(.white)
                }
                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#50C878")))
                .padding(.horizontal)
                .onChange(of: viewModel.germanDubOnly) { _ in
                    viewModel.toggleGermanDub()
                }
                
                // MARK: Anime Grid
                if viewModel.animeList.isEmpty && viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#50C878")))
                        .scaleEffect(1.5)
                        .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: animeColumns, spacing: 12) {
                            ForEach(viewModel.animeList) { anime in
                                GenreAnimeCardView(anime: anime)
                            }
                        }
                        .padding(.horizontal)
                        
                        // MARK: Load More Button
                        if viewModel.hasMore {
                            Button(action: {
                                Task { await viewModel.loadMore() }
                            }) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Weitere laden")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color(hex: "#50C878"))
                                        .cornerRadius(8)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Genres")
            .background(Color(hex: "#090B10").ignoresSafeArea())
        }
        .accentColor(Color(hex: "#50C878"))
    }
}

// MARK: - Preview

struct GenresView_Previews: PreviewProvider {
    static var previews: some View {
        GenresView()
            .preferredColorScheme(.dark)
    }
}