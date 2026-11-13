import SwiftUI

// MARK: - Model

struct WatchedAnime: Identifiable, Equatable {
    let id: UUID
    let title: String
    let thumbnailURL: URL?
    let episodeNumber: Int
    let progress: Double   // 0.0 … 1.0
}

// MARK: - Storage Service

private final class HistoryStorageService {
    static let shared = HistoryStorageService()
    
    private var storedHistory: [WatchedAnime] = []
    
    private init() {
        storedHistory = [
            WatchedAnime(
                id: UUID(),
                title: "Attack on Titan",
                thumbnailURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx16498-C6FPmWm59CyP.jpg"),
                episodeNumber: 12,
                progress: 0.45
            ),
            WatchedAnime(
                id: UUID(),
                title: "Solo Leveling",
                thumbnailURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx151807-312948.png"),
                episodeNumber: 5,
                progress: 0.80
            )
        ]
    }
    
    func fetchHistory() async -> [WatchedAnime] {
        // Simulate async fetch
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 sec
        return storedHistory
    }
    
    func clearHistory() async {
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 sec
        storedHistory.removeAll()
    }
}

// MARK: - ViewModel

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var history: [WatchedAnime] = []
    @Published var isLoading = false
    
    private let storage = HistoryStorageService.shared
    
    func loadHistory() async {
        isLoading = true
        history = await storage.fetchHistory()
        isLoading = false
    }
    
    func clearHistory() async {
        await storage.clearHistory()
        history.removeAll()
    }
}

// MARK: - View

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showClearAlert = false
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.history.isEmpty {
                    VStack {
                        Spacer()
                        Text("Noch kein Verlauf vorhanden")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    List(viewModel.history) { anime in
                        let targetAnime = Anime.curatedList.first(where: { $0.title.localizedCaseInsensitiveContains(anime.title) }) ?? Anime(title: anime.title, posterURL: anime.thumbnailURL)
                        NavigationLink(destination: DetailView(anime: targetAnime)) {
                            HistoryRow(anime: anime, resumeAction: {})
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Verlauf & Fortsetzen")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Verlauf komplett leeren") {
                        showClearAlert = true
                    }
                    .foregroundStyle(.red)
                }
            }
            .alert("Verlauf leeren", isPresented: $showClearAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Leeren", role: .destructive) {
                    Task {
                        await viewModel.clearHistory()
                    }
                }
            } message: {
                Text("Möchten Sie wirklich den gesamten Verlauf löschen?")
            }
            .task {
                await viewModel.loadHistory()
            }
        }
    }
}

// MARK: - Row

struct HistoryRow: View {
    let anime: WatchedAnime
    let resumeAction: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: anime.thumbnailURL) { phase in
                switch phase {
                case .empty:
                    Color.gray.opacity(0.2)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Color.gray.opacity(0.2)
                @unknown default:
                    Color.gray.opacity(0.2)
                }
            }
            .frame(width: 80, height: 45)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(anime.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("Folge \(anime.episodeNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView(value: anime.progress)
                    .progressViewStyle(.linear)
            }
            
            Spacer()
            
            Button(action: resumeAction) {
                Image(systemName: "play.fill")
                    .font(.title2)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#if DEBUG
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
#endif