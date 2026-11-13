import SwiftUI
import Combine

enum SearchFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case gerDub = "Ger Dub"
    
    var id: String { rawValue }
}

struct Anime: Identifiable {
    let id: UUID = UUID()
    let title: String
    let imageURL: URL?
}

class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var filter: SearchFilter = .all
    @Published var results: [Anime] = []
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        Publishers.CombineLatest(
            $query
                .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
                .removeDuplicates(),
            $filter
        )
        .sink { [weak self] (query, filter) in
            self?.performSearch(query: query, filter: filter)
        }
        .store(in: &cancellables)
    }
    
    private func performSearch(query: String, filter: SearchFilter) {
        guard !query.isEmpty else {
            results = []
            return
        }
        isLoading = true
        Task {
            do {
                let fetched = try await AniworldEngine.search(query: query, filter: filter)
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
                        ForEach(vm.results) { anime in
                            NavigationLink(destination: AnimeDetailView(anime: anime)) {
                                AnimeGridItem(anime: anime)
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
    let anime: Anime
    
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
            .frame(height: 150)
            .cornerRadius(8)
            
            Text(anime.title)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }
}

struct AnimeDetailView: View {
    let anime: Anime
    
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