import SwiftUI
import Combine

enum SearchFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case gerDub = "Ger Dub"
    
    var id: String { rawValue }
}

struct SearchAnime: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let imageURL: URL?
    let url: String

    init(id: UUID = UUID(), title: String, imageURL: URL? = nil, url: String = "") {
        self.id = id
        self.title = title
        self.imageURL = imageURL
        self.url = url
    }
}

class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var filter: SearchFilter = .all
    @Published var results: [SearchAnime] = []
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        Publishers.CombineLatest(
            $query
                .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)
                .removeDuplicates(),
            $filter
        )
        .sink { [weak self] (query, filter) in
            self?.performSearch(query: query, filter: filter)
        }
        .store(in: &cancellables)
        
        performSearch(query: "", filter: .all)
    }
    
    private func performSearch(query: String, filter: SearchFilter) {
        isLoading = true
        Task {
            do {
                let items: [MediaItem]
                if query.isEmpty {
                    items = Anime.curatedList.prefix(16).map { anime in
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
                } else {
                    items = try await AniworldEngine.shared.search(keyword: query)
                }
                let filtered = (filter == .gerDub) ? items.filter { it in
                    it.tags.contains(where: { $0.localizedCaseInsensitiveContains("ger") || $0.localizedCaseInsensitiveContains("dub") })
                } : items
                let fetched = filtered.map { SearchAnime(title: $0.title, imageURL: $0.coverURL, url: $0.url) }
                await MainActor.run {
                    self.results = fetched
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.results = []
                    self.isLoading = false
                }
            }
        }
    }
    
    func clear() {
        query = ""
    }
}

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search anime...", text: $vm.query)
                        .foregroundColor(.primary)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                    if !vm.query.isEmpty {
                        Button(action: { vm.clear() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
                
                Picker("Filter", selection: $vm.filter) {
                    ForEach(SearchFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                if vm.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                }
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(vm.results) { item in
                            let targetAnime = Anime.curatedList.first(where: { $0.url == item.url || $0.title.localizedCaseInsensitiveContains(item.title) }) ?? Anime(title: item.title, posterURL: item.imageURL, url: item.url)
                            NavigationLink(destination: DetailView(anime: targetAnime)) {
                                AnimeGridItem(anime: item)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Search")
            .background(Color.black.ignoresSafeArea())
        }
        .preferredColorScheme(.dark)
    }
}

struct AnimeGridItem: View {
    let anime: SearchAnime
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: anime.imageURL) { phase in
                switch phase {
                case .empty:
                    Color(hex: "#1A1C22")
                        .frame(height: 190)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 190)
                        .clipped()
                case .failure:
                    Color(hex: "#1A1C22")
                        .frame(height: 190)
                        .overlay {
                            Image(systemName: "film")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                @unknown default:
                    Color(hex: "#1A1C22")
                        .frame(height: 190)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
            )
            
            Text(anime.title)
                .font(.caption.bold())
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .padding(8)
        .background(Color(hex: "#141519"))
        .cornerRadius(12)
    }
}

struct AnimeDetailView: View {
    let anime: SearchAnime
    
    var body: some View {
        VStack {
            AsyncImage(url: anime.imageURL) { phase in
                switch phase {
                case .empty:
                    Color.gray.opacity(0.3)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.secondary)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxHeight: 300)
            .padding()
            
            Text(anime.title)
                .font(.title2)
                .foregroundColor(.white)
                .padding()
            
            Spacer()
        }
        .navigationTitle(anime.title)
        .background(Color.black.ignoresSafeArea())
    }
}