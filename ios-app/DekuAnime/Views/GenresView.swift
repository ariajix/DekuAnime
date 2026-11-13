import SwiftUI



// MARK: - Models

struct GenreAnime: Identifiable, Hashable {
    let id: UUID = UUID()
    let title: String
    let imageURL: URL?
    let isGermanDub: Bool
    let url: String

    init(title: String, imageURL: URL?, isGermanDub: Bool = true, url: String = "") {
        self.title = title
        self.imageURL = imageURL
        self.isGermanDub = isGermanDub
        self.url = url
    }
}

// MARK: - Data Provider

class AnimeService {
    static let shared = AnimeService()
    
    static let allGenres: [(name: String, slug: String)] = [
        ("Action", "action"),
        ("Abenteuer", "abenteuer"),
        ("Shōnen", "fighting-shounen"),
        ("Isekai", "fantasy"),
        ("Fantasy", "fantasy"),
        ("Magie", "magical-girl"),
        ("Romance", "romanze"),
        ("Drama", "drama"),
        ("Comedy", "komoedie"),
        ("Slice of Life", "alltagsleben"),
        ("Sci-Fi", "scifi"),
        ("Mecha", "mecha"),
        ("Mystery", "mystery"),
        ("Horror", "horror"),
        ("Psychologisch", "psychodrama"),
        ("Thriller", "thriller"),
        ("Sport", "sport"),
        ("Supernatural", "geistergeschichten"),
        ("Dämonen", "geistergeschichten"),
        ("Militär", "action"),
        ("Schulleben", "alltagsleben"),
        ("Musik", "alltagsleben"),
        ("Ecchi", "ecchi"),
        ("Nur Ger Dub", "ger")
    ]
    
    func fetchGenres() -> [String] {
        Self.allGenres.map { $0.name }
    }
    
    func slugForGenre(_ genreName: String) -> String {
        Self.allGenres.first(where: { $0.name.caseInsensitiveCompare(genreName) == .orderedSame })?.slug ?? genreName.lowercased()
    }
    
    func fetchGenreAnime(
        genre: String,
        germanDubOnly: Bool,
        offset: Int,
        limit: Int
    ) async throws -> [GenreAnime] {
        let slug = slugForGenre(genre)
        let isDubFilter = germanDubOnly || genre == "Nur Ger Dub"
        let page = (offset / limit) + 1
        
        if let (items, _) = try? await AniworldEngine.shared.fetchGenre(slug: slug, page: page), !items.isEmpty {
            let filtered = isDubFilter ? items.filter { $0.isGerDub } : items
            return filtered.map {
                GenreAnime(title: $0.title, imageURL: $0.posterURL, isGermanDub: $0.isGerDub, url: $0.url)
            }
        }
        
        let matching = Anime.curatedList.filter { anime in
            let matchesGenre = genre.isEmpty || anime.genres.contains { g in
                g.localizedCaseInsensitiveContains(genre) ||
                (genre.contains("Shōnen") && (g.contains("Shonen") || g.contains("Action")))
            }
            let matchesDub = !isDubFilter || anime.hasGermanDub
            return matchesGenre && matchesDub
        }
        let list = matching.isEmpty ? Anime.curatedList : matching
        let paged = list.dropFirst(offset).prefix(limit)
        return paged.map { anime in
            GenreAnime(
                title: anime.title,
                imageURL: anime.posterURL,
                isGermanDub: anime.hasGermanDub,
                url: anime.url
            )
        }
    }
}

// MARK: - ViewModel

@MainActor
class GenresViewModel: ObservableObject {
    @Published var selectedGenre: String = "Action"
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
    
    init() {
        selectGenre("Action")
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
            .frame(height: 145)
            .clipped()
            .cornerRadius(8)
            
            Text(anime.title)
                .font(.caption.bold())
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 4)
            
            Text(anime.isGermanDub ? "🇩🇪 DUB" : "🇩🇪 SUB")
                .font(.caption2.bold())
                .foregroundColor(anime.isGermanDub ? Color(hex: "#10B981") : Color.cyan)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08))
                .cornerRadius(4)
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
    @State private var isDropdownExpanded = false
    
    private let animeColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                // MARK: - Dropdown Header Button
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isDropdownExpanded.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: "square.grid.2x2.fill")
                            .foregroundColor(Color(hex: "#10B981"))
                        Text(viewModel.selectedGenre.isEmpty ? "Genre wählen" : viewModel.selectedGenre)
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: isDropdownExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "#10B981"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#141519"))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#10B981").opacity(0.35), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                // MARK: - Dropdown Content (Animated 2-Column Grid)
                if isDropdownExpanded {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(viewModel.availableGenres, id: \.self) { genre in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    viewModel.selectGenre(genre)
                                    isDropdownExpanded = false
                                }
                            }) {
                                HStack {
                                    Text(genre)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(viewModel.selectedGenre == genre ? .black : .white)
                                        .lineLimit(1)
                                    Spacer()
                                    if viewModel.selectedGenre == genre {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundColor(.black)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(viewModel.selectedGenre == genre ? Color(hex: "#10B981") : Color(hex: "#1A1C22"))
                                )
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(hex: "#101216"))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // MARK: German Dub Filter
                Toggle(isOn: $viewModel.germanDubOnly) {
                    Text("Nur Ger Dub")
                        .foregroundColor(.white)
                }
                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#10B981")))
                .padding(.horizontal)
                .onChange(of: viewModel.germanDubOnly) { _ in
                    viewModel.toggleGermanDub()
                }
                
                // MARK: Anime Grid
                if viewModel.animeList.isEmpty && viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#10B981")))
                        .scaleEffect(1.5)
                        .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: animeColumns, spacing: 12) {
                            ForEach(viewModel.animeList) { anime in
                                let targetAnime = Anime.curatedList.first(where: { $0.url == anime.url || $0.title.localizedCaseInsensitiveContains(anime.title) }) ?? Anime(title: anime.title, posterURL: anime.imageURL, hasGermanDub: anime.isGermanDub, url: anime.url)
                                NavigationLink(destination: DetailView(anime: targetAnime)) {
                                    GenreAnimeCardView(anime: anime)
                                }
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
                                        .background(Color(hex: "#10B981"))
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
        .accentColor(Color(hex: "#10B981"))
    }
}

// MARK: - Preview

struct GenresView_Previews: PreviewProvider {
    static var previews: some View {
        GenresView()
            .preferredColorScheme(.dark)
    }
}