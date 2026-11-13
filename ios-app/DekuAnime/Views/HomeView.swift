import SwiftUI

// MARK: - Models

struct Anime: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let imageName: String   // Use asset name or system image for placeholder
    let rank: Int?
}

// MARK: - Sample Data

extension Anime {
    static let sampleTrending = Anime(title: "Demon Slayer", imageName: "hero1", rank: nil)
    static let sampleList: [Anime] = (1...20).map {
        Anime(title: "Anime \($0)", imageName: "thumb\($0 % 5 + 1)", rank: nil)
    }
    static let sampleMega100: [Anime] = (1...100).map {
        Anime(title: "Anime \($0)", imageName: "thumb\($0 % 5 + 1)", rank: $0)
    }
    static let samplePopular: [Anime] = (1...10).map {
        Anime(title: "Popular \($0)", imageName: "thumb\($0 % 5 + 1)", rank: nil)
    }
    static let sampleNew: [Anime] = (1...10).map {
        Anime(title: "New \($0)", imageName: "thumb\($0 % 5 + 1)", rank: nil)
    }
}

// MARK: - HomeView

struct HomeView: View {
    @State private var isGerman = false
    @State private var trendingAnime: Anime = Anime.sampleTrending
    @State private var mega100 = Anime.sampleMega100
    @State private var popularSeries = Anime.samplePopular
    @State private var newReleases = Anime.sampleNew
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    topBar
                    heroBanner
                    mega100Section
                    seriesSection(title: "Beliebte Serien", items: popularSeries)
                    seriesSection(title: "Neuerscheinungen", items: newReleases)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .refreshable {
                await loadData()
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Image("deku_logo")
                .resizable()
                .scaledToFit()
                .frame(height: 32)
            
            Spacer()
            
            Toggle(isOn: $isGerman) {
                Text("Ger Dub")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(12)
            }
            .toggleStyle(.button)
            .labelsHidden()
            
            Spacer()
            
            NavigationLink(destination: ProfileView()) {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle")
                        .font(.title2)
                    Text("Hey, Deku")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(20)
            }
        }
    }
    
    // MARK: - Hero Banner
    
    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            Image(trendingAnime.imageName)
                .resizable()
                .scaledToFill()
                .frame(height: 240)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(trendingAnime.title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                NavigationLink(destination: DetailView(anime: trendingAnime)) {
                    Text("Mehr ansehen")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .cornerRadius(12)
    }
    
    // MARK: - Mega 100 Section
    
    private var mega100Section: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mega 100")
                    .font(.title3.bold())
                Spacer()
                NavigationLink(destination: Mega100GridView(animes: mega100)) {
                    Text("Alle anzeigen >")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(mega100.prefix(10)) { anime in
                        NavigationLink(destination: DetailView(anime: anime)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Image(anime.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 180)
                                    .clipped()
                                    .cornerRadius(8)
                                
                                Text(anime.title)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                if let rank = anime.rank {
                                    Text("#\(rank)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Series Sections
    
    private func seriesSection(title: String, items: [Anime]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { anime in
                        NavigationLink(destination: DetailView(anime: anime)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Image(anime.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 150)
                                    .clipped()
                                    .cornerRadius(8)
                                
                                Text(anime.title)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        // In a real app, replace with API calls.
        // For demo, shuffle data.
        trendingAnime = Anime.sampleTrending
        mega100.shuffle()
        popularSeries.shuffle()
        newReleases.shuffle()
    }
}

// MARK: - Mega100GridView

struct Mega100GridView: View {
    let animes: [Anime]
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(animes) { anime in
                    NavigationLink(destination: DetailView(anime: anime)) {
                        HStack(spacing: 12) {
                            Image(anime.imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipped()
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(anime.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                if let rank = anime.rank {
                                    Text("TOP \(rank)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Mega 100")
    }
}

// MARK: - DetailView (Placeholder)

struct DetailView: View {
    let anime: Anime
    
    var body: some View {
        VStack {
            Image(anime.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .cornerRadius(12)
                .padding()
            
            Text(anime.title)
                .font(.largeTitle.bold())
                .padding(.bottom, 8)
            
            Text("Detailed description goes here. This is a placeholder view for the selected anime.")
                .font(.body)
                .padding()
            
            Spacer()
        }
        .navigationTitle(anime.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ProfileView (Placeholder)

struct ProfileView: View {
    var body: some View {
        VStack {
            Text("Profile")
                .font(.largeTitle.bold())
            Spacer()
        }
        .padding()
        .navigationTitle("Hey, Deku")
    }
}

// MARK: - Preview

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}