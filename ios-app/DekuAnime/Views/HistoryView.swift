import SwiftUI

// MARK: - View

struct HistoryView: View {
    @ObservedObject private var storage = StorageService.shared
    @State private var showClearAlert = false
    @State private var selectedPlayerItem: HistoryPlayerItem? = nil
    @State private var isResolving = false
    
    struct HistoryPlayerItem: Identifiable {
        let id = UUID()
        let streamURL: URL
        let animeTitle: String
        let episodeTitle: String
        let posterUrl: String
        let seriesUrl: String
        let episodeUrl: String
        let seasonNumber: Int
        let episodeNumber: Int
        let position: Double
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if storage.history.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Noch kein Verlauf vorhanden")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Starte eine Episode, um sie hier fortzusetzen.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(storage.history) { entry in
                            HistoryRow(entry: entry) {
                                resumeEpisode(entry)
                            }
                            .listRowBackground(Color(hex: "#101216"))
                            .listRowSeparatorTint(Color.white.opacity(0.1))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Verlauf & Fortsetzen")
            .background(Color(hex: "#090B10").ignoresSafeArea())
            .toolbar {
                if !storage.history.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            showClearAlert = true
                        } label: {
                            Text("Leeren")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .alert("Verlauf leeren", isPresented: $showClearAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Leeren", role: .destructive) {
                    withAnimation {
                        storage.clearHistory()
                    }
                }
            } message: {
                Text("Möchtest du wirklich den gesamten Verlauf löschen?")
            }
            .overlay {
                if isResolving {
                    ZStack {
                        Color.black.opacity(0.7).ignoresSafeArea()
                        ProgressView("Lade Stream...")
                            .tint(Color(hex: "#10B981"))
                            .foregroundColor(.white)
                    }
                }
            }
            .fullScreenCover(item: $selectedPlayerItem) { item in
                PlayerView(
                    url: item.streamURL,
                    animeTitle: item.animeTitle,
                    episodeTitle: item.episodeTitle,
                    posterUrl: item.posterUrl,
                    seriesUrl: item.seriesUrl,
                    episodeUrl: item.episodeUrl,
                    seasonNumber: item.seasonNumber,
                    episodeNumber: item.episodeNumber,
                    initialTime: item.position
                )
            }
        }
    }
    
    private func resumeEpisode(_ entry: HistoryEntry) {
        guard !entry.episodeUrl.isEmpty else { return }
        isResolving = true
        Task {
            do {
                let streamUrl = try await AniworldEngine.shared.resolveStream(episodeUrl: entry.episodeUrl)
                await MainActor.run {
                    self.isResolving = false
                    self.selectedPlayerItem = HistoryPlayerItem(
                        streamURL: streamUrl,
                        animeTitle: entry.animeTitle,
                        episodeTitle: "Staffel \(entry.season) Episode \(entry.episode) - \(entry.episodeTitle)",
                        posterUrl: entry.posterUrl,
                        seriesUrl: entry.seriesUrl,
                        episodeUrl: entry.episodeUrl,
                        seasonNumber: entry.season,
                        episodeNumber: entry.episode,
                        position: entry.position
                    )
                }
            } catch {
                await MainActor.run {
                    self.isResolving = false
                }
            }
        }
    }
}

// MARK: - HistoryRow

private struct HistoryRow: View {
    let entry: HistoryEntry
    let resumeAction: () -> Void
    
    var body: some View {
        Button(action: resumeAction) {
            HStack(spacing: 12) {
                // Thumbnail
                AsyncImage(url: URL(string: entry.posterUrl)) { phase in
                    switch phase {
                    case .empty:
                        Color(hex: "#1A1C22")
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Color(hex: "#1A1C22")
                            .overlay {
                                Image(systemName: "film")
                                    .foregroundColor(.gray)
                            }
                    @unknown default:
                        Color(hex: "#1A1C22")
                    }
                }
                .frame(width: 65, height: 95)
                .clipped()
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.animeTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("Staffel \(entry.season) • Folge \(entry.episode)")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#10B981"))
                    
                    if !entry.episodeTitle.isEmpty {
                        Text(entry.episodeTitle)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    // Time Info & Progress Bar
                    if entry.duration > 0 {
                        ProgressView(value: min(entry.position / entry.duration, 1.0))
                            .tint(Color(hex: "#10B981"))
                        Text("Minute \(Int(entry.position / 60)) von \(Int(entry.duration / 60)) Min")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else if entry.position > 0 {
                        Text("Fortsetzen bei \(Int(entry.position / 60)) Min")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: "#10B981"))
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
