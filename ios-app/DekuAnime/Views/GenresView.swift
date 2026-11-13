import SwiftUI

// MARK: - Helpers

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Models

struct Anime: Identifiable, Hashable {
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
    func fetchAnime(
        genre: String,
        germanDubOnly: Bool,
        offset: Int,
        limit: Int
    ) async throws -> [Anime] {
        // Simulate network latency
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Generate dummy titles
        let base = germanDubOnly ? "GER Dub" : "ENG"
        return (offset..<offset+limit).map { i in
            Anime(
                title: "\(genre) \(base) Title \(i + 1)",
                imageURL: nil,
                isGermanDub: germanDubOnly
            )
        }
    }
}

// MARK: - ViewModel

@MainActor
class GenresViewModel: ObservableObject {
    @Published var selectedGenre: String = ""
    @Published var germanDubOnly: Bool = false
    @Published var animeList: [Anime] = []
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
            let newItems = try await service.fetchAnime(
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

struct AnimeCardView: View {
    let anime: Anime
    
    var body: some View {
        VStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(3/4, contentMode: .fit)
                .overlay(
                    Text(anime.title.prefix(1))
                        .font(.largeTitle)
                        .foregroundColor(.white)
                )
            Text(anime.title)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding([.horizontal, .bottom], 4)
        }
        .background(Color(hex: "#1E2127"))
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
                                AnimeCardView(anime: anime)
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