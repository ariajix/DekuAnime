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
                        WatchlistItemView(anime: anime, onRemove: {
                            itemToDelete = anime
                            showingDeleteConfirmation = true
                        })
                    }
                    .buttonStyle(.plain)
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
    var onRemove: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: anime.coverURL) { phase in
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
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                )

                // Delete Button on Card
                if let onRemove = onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.red.opacity(0.85))
                            .clipShape(Circle())
                    }
                    .padding(6)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(anime.title)
                    .font(.caption.bold())
                    .lineLimit(2)
                    .foregroundColor(.white)

                Text(anime.hasGermanDub ? "🇩🇪 DUB" : "🇩🇪 SUB")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(anime.hasGermanDub ? Color(hex: "#10B981") : Color.cyan)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(4)
            }
        }
        .padding(8)
        .background(Color(hex: "#141519"))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
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