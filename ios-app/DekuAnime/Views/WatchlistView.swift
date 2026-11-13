import SwiftUI

// MARK: - WatchlistView
struct WatchlistView: View {
    @StateObject private var storage = StorageService.shared
    @State private var showingDeleteConfirmation = false
    @State private var itemToDelete: AnimeItem?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                header
                if storage.watchlistAnimes.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .padding(.horizontal, 16)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Eintrag entfernen?", isPresented: $showingDeleteConfirmation, actions: {
            Button("Abbrechen", role: .cancel) { itemToDelete = nil }
            Button("Entfernen", role: .destructive) {
                if let item = itemToDelete {
                    storage.removeFromWatchlist(item)
                }
                itemToDelete = nil
            }
        })
    }

    // MARK: - Header
    private var header: some View {
        Text("Meine Bibliothek")
            .font(.title2.bold())
            .foregroundStyle(.primary)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Deine Bibliothek ist leer.")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Füge Anime hinzu, um sie hier zu sehen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Grid
    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(storage.watchlistAnimes) { anime in
                    NavigationLink(value: anime) {
                        WatchlistItemView(anime: anime)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            itemToDelete = anime
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Entfernen", systemImage: "trash")
                        }
                    }
                }
            }
            .animation(.default, value: storage.watchlistAnimes)
        }
        .navigationDestination(for: AnimeItem.self) { anime in
            DetailView(anime: anime)
        }
    }
}

// MARK: - WatchlistItemView
private struct WatchlistItemView: View {
    let anime: AnimeItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: anime.coverURL) { phase in
                switch phase {
                case .empty:
                    Color.gray.opacity(0.2)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(anime.title)
                .font(.caption)
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct WatchlistView_Previews: PreviewProvider {
    static var previews: some View {
        WatchlistView()
            .environmentObject(StorageService.shared)
    }
}
#endif